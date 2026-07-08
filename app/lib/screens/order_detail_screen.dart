import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:velo_core/velo_core.dart';

import '../providers/app_providers.dart';
import '../utils/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/swipe_confirm.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _checkout;
  bool _loading = true;
  XFile? _podPhoto;
  Position? _riderPos;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _load();
    _startRiderLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _startRiderLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final allowed = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
      if (!allowed) return;

      _riderPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() {});

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((p) {
        _riderPos = p;
        if (mounted) setState(() {});
      });
    } catch (_) {
      // Ignore permission/GPS errors; map will simply hide rider marker.
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final assignments = await ref.read(apiProvider).get('/rider/assignments');
      final all = await ref.read(apiProvider).get('/rider/orders', query: {'filter': 'all'});
      final combined = [
        ...((assignments.data['data'] as List?) ?? []),
        ...((all.data['data'] as List?) ?? []),
      ];
      Map<String, dynamic>? found;
      for (final item in combined) {
        final map = item as Map<String, dynamic>;
        if (map['id'] == widget.orderId) {
          found = map;
          break;
        }
      }
      setState(() {
        _order = found;
        _checkout = null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    await ref.read(apiProvider).post('/rider/orders/${widget.orderId}/accept');
    ref.invalidate(assignmentsProvider);
    await _load();
  }

  Future<void> _reject() async {
    await ref.read(apiProvider).post('/rider/orders/${widget.orderId}/reject', data: {'reason': 'Not available'});
    ref.invalidate(assignmentsProvider);
    if (mounted) context.pop();
  }

  Future<void> _failed() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Failed delivery'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(labelText: 'Reason', hintText: 'Customer not available'),
            maxLines: 3,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Submit')),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    await ref.read(apiProvider).post('/rider/orders/${widget.orderId}/failed', data: {'reason': reason});
    ref.invalidate(assignmentsProvider);
    if (mounted) context.pop();
  }

  Future<void> _pickedUp() async {
    await ref.read(apiProvider).post('/rider/orders/${widget.orderId}/picked-up');
    ref.invalidate(assignmentsProvider);
    ref.invalidate(riderOrdersProvider('all'));
    await _load();
  }

  Future<void> _delivered() async {
    if (_podPhoto != null) {
      final form = FormData.fromMap({
        'pod_photo': await MultipartFile.fromFile(_podPhoto!.path, filename: 'pod.jpg'),
      });
      await ref.read(apiProvider).postMultipart('/rider/orders/${widget.orderId}/delivered', form);
    } else {
      await ref.read(apiProvider).post('/rider/orders/${widget.orderId}/delivered');
    }
    ref.invalidate(assignmentsProvider);
    ref.invalidate(riderStatsProvider);
    if (mounted) context.pop();
  }

  Future<void> _pickPodPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
    if (file != null) setState(() => _podPhoto = file);
  }

  Future<void> _loadCheckout() async {
    final res = await ref.read(apiProvider).get('/rider/orders/${widget.orderId}/checkout');
    setState(() => _checkout = res.data['data'] as Map<String, dynamic>);
  }

  double? get _deliveryLat => JsonNum.parseDouble(_order?['delivery_lat']);
  double? get _deliveryLng => JsonNum.parseDouble(_order?['delivery_lng']);

  bool get _hasDeliveryPin => _deliveryLat != null && _deliveryLng != null;

  bool get _isCompletedLike {
    final status = _order?['order_status']?.toString();
    return status == 'delivered' || status == 'cancelled' || status == 'returned';
  }

  Future<void> _openDeliveryNavigation() async {
    if (!_hasDeliveryPin) return;
    final ok = await NavigationUtils.openExternalNavigation(lat: _deliveryLat!, lng: _deliveryLng!);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps app')),
      );
    }
  }

  bool get _isPendingAssignment => _order?['assignment_status']?.toString() == 'pending';

  bool get _canAct {
    final status = _order?['order_status']?.toString();
    if (_isPendingAssignment) return false;
    return status == 'dispatched' || status == 'picked_up' || status == 'ready_to_ship';
  }

  Widget _buildMapSection(ThemeData theme) {
    final colors = theme.colorScheme;

    if (!_hasDeliveryPin) {
      return Card(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.location_off_outlined, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Customer location not set',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final delivery = LatLng(_deliveryLat!, _deliveryLng!);
    final rider = _riderPos != null ? LatLng(_riderPos!.latitude, _riderPos!.longitude) : null;
    final center = rider ?? delivery;

    final markers = <Marker>[
      Marker(
        point: delivery,
        width: 44,
        height: 44,
        child: Icon(Icons.location_pin, color: colors.error, size: 44),
      ),
      if (rider != null)
        Marker(
          point: rider,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: colors.onPrimary, width: 2),
            ),
            child: Icon(Icons.delivery_dining, color: colors.onPrimary, size: 18),
          ),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14.5,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'pk.velo.prorider_rider_app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Order not found'))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _order!['order_reference_number'] ?? '',
                              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          StatusChip(status: _order!['order_status']?.toString() ?? ''),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(icon: Icons.person_outline, label: 'Customer', value: _order!['customer_name']?.toString() ?? '—'),
                      _DetailRow(icon: Icons.phone_outlined, label: 'Phone', value: _order!['customer_phone']?.toString() ?? '—'),
                      _DetailRow(icon: Icons.location_on_outlined, label: 'Address', value: _order!['delivery_address']?.toString() ?? '—'),
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.my_location_outlined,
                        label: 'Delivery pin',
                        value: _hasDeliveryPin ? '${_deliveryLat!.toStringAsFixed(6)}, ${_deliveryLng!.toStringAsFixed(6)}' : '—',
                      ),
                      _buildMapSection(theme),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _hasDeliveryPin ? _openDeliveryNavigation : null,
                        icon: const Icon(Icons.navigation_outlined),
                        label: const Text('Navigate to delivery'),
                      ),
                      _DetailRow(icon: Icons.location_city_outlined, label: 'City', value: _order!['target_city']?.toString() ?? '—'),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        label: 'COD',
                        value: '₨ ${_order!['cod_amount'] ?? '0'}',
                        highlight: true,
                      ),
                      const Spacer(),
                      if (_isPendingAssignment) ...[
                        Card(
                          color: Colors.orange.withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('New assignment — accept to start delivery'),
                                const SizedBox(height: 12),
                                FilledButton(onPressed: _accept, child: const Text('Accept')),
                                const SizedBox(height: 8),
                                OutlinedButton(onPressed: _reject, child: const Text('Reject')),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (!_isCompletedLike && _canAct && _order!['order_status'] != 'picked_up') ...[
                        SwipeConfirm(label: 'Swipe to confirm picked up', onComplete: _pickedUp),
                        const SizedBox(height: 16),
                      ],
                      if (!_isCompletedLike && _canAct && _order!['order_status'] == 'picked_up') ...[
                        OutlinedButton.icon(
                          onPressed: _failed,
                          icon: const Icon(Icons.error_outline),
                          label: const Text('Could not deliver'),
                        ),
                        const SizedBox(height: 12),
                        if (_checkout == null)
                          FilledButton(
                            onPressed: _loadCheckout,
                            child: const Text('Open checkout', style: TextStyle(fontSize: 18)),
                          )
                        else ...[
                          if (_checkout!['bank_transfer'] != null)
                            Center(child: QrImageView(data: _checkout!['bank_transfer']['qr_payload'], size: 200))
                          else
                            Text(_checkout!['terms'] ?? '', style: textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _pickPodPhoto,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(_podPhoto == null ? 'Add delivery photo (optional)' : 'Photo attached'),
                          ),
                          const SizedBox(height: 12),
                          SwipeConfirm(
                            label: 'Swipe to confirm delivered',
                            color: AppTheme.success,
                            onComplete: _delivered,
                          ),
                        ],
                      ],
                      if (_isCompletedLike || !_canAct)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _isCompletedLike ? 'This order is completed.' : 'This order is no longer active.',
                              style: TextStyle(color: colors.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: highlight ? 20 : 16,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                    color: highlight ? AppTheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
