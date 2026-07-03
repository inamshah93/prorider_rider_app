import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:velo_core/velo_core.dart';

import '../providers/app_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _openMaps() async {
    final address = _order?['delivery_address']?.toString();
    if (address == null || address.isEmpty) return;
    final city = _order?['target_city']?.toString() ?? '';
    final query = Uri.encodeComponent('$address $city'.trim());
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _isPendingAssignment => _order?['assignment_status']?.toString() == 'pending';

  bool get _canAct {
    final status = _order?['order_status']?.toString();
    if (_isPendingAssignment) return false;
    return status == 'dispatched' || status == 'picked_up' || status == 'ready_to_ship';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                      if (_canAct)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OutlinedButton.icon(
                            onPressed: _openMaps,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Navigate with Google Maps'),
                          ),
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
                      if (_canAct && _order!['order_status'] != 'picked_up') ...[
                        SwipeConfirm(label: 'Swipe to confirm picked up', onComplete: _pickedUp),
                        const SizedBox(height: 16),
                      ],
                      if (_canAct && _order!['order_status'] == 'picked_up') ...[
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
                      if (!_canAct)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'This order is completed or no longer active.',
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
