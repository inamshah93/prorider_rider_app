import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:velo_core/velo_core.dart';

final apiProvider = Provider((ref) => ApiClient());
final authRepoProvider = Provider((ref) => AuthRepository(ref.watch(apiProvider)));

void main() => runApp(const ProviderScope(child: RiderApp()));

class RiderApp extends ConsumerWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.light();
    return MaterialApp(
      title: 'Velo Rider',
      theme: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
          headlineMedium: theme.textTheme.headlineMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
      home: const RiderHome(),
    );
  }
}

class RiderHome extends ConsumerStatefulWidget {
  const RiderHome({super.key});

  @override
  ConsumerState<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends ConsumerState<RiderHome> {
  bool _loggedIn = false;
  Map<String, dynamic>? _activeOrder;
  Map<String, dynamic>? _checkout;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await ref.read(authRepoProvider).login('rider@velo.pk', 'password');
      setState(() => _loggedIn = true);
      await _loadAssignments();
    } catch (_) {}
  }

  Future<void> _loadAssignments() async {
    final res = await ref.read(apiProvider).get('/rider/assignments');
    final list = (res.data['data'] as List?) ?? [];
    if (list.isNotEmpty) setState(() => _activeOrder = list.first as Map<String, dynamic>);
  }

  Future<void> _pickedUp() async {
    await ref.read(apiProvider).post('/rider/orders/${_activeOrder!['id']}/picked-up');
    await _loadAssignments();
  }

  Future<void> _delivered() async {
    await ref.read(apiProvider).post('/rider/orders/${_activeOrder!['id']}/delivered');
    setState(() {
      _activeOrder = null;
      _checkout = null;
    });
    await _loadAssignments();
  }

  Future<void> _loadCheckout() async {
    final res = await ref.read(apiProvider).get('/rider/orders/${_activeOrder!['id']}/checkout');
    setState(() => _checkout = res.data['data'] as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Velo Rider', style: TextStyle(fontSize: 24))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _activeOrder == null
            ? Center(child: Text('Waiting for orders…', style: textTheme.titleLarge?.copyWith(color: colors.onSurfaceVariant)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_activeOrder!['order_reference_number'] ?? '', style: textTheme.headlineMedium?.copyWith(color: colors.onSurface)),
                  const SizedBox(height: 8),
                  Text(_activeOrder!['delivery_address'] ?? '', style: textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('COD: ₨ ${_activeOrder!['cod_amount']}', style: textTheme.titleLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_checkout == null) ...[
                    SwipeConfirm(label: 'Swipe to confirm picked up', onComplete: _pickedUp),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _loadCheckout, child: const Text('Open checkout', style: TextStyle(fontSize: 20))),
                  ] else ...[
                    if (_checkout!['bank_transfer'] != null)
                      Center(
                        child: QrImageView(data: _checkout!['bank_transfer']['qr_payload'], size: 220),
                      )
                    else
                      Text(_checkout!['terms'] ?? '', style: textTheme.bodyLarge?.copyWith(color: colors.onSurface)),
                    const SizedBox(height: 16),
                    SwipeConfirm(label: 'Swipe to confirm delivered', color: AppTheme.success, onComplete: _delivered),
                  ],
                ],
              ),
      ),
    );
  }
}

class SwipeConfirm extends StatefulWidget {
  const SwipeConfirm({super.key, required this.label, required this.onComplete, this.color = AppTheme.primary});
  final String label;
  final Future<void> Function() onComplete;
  final Color color;

  @override
  State<SwipeConfirm> createState() => _SwipeConfirmState();
}

class _SwipeConfirmState extends State<SwipeConfirm> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final max = c.maxWidth - 72;
      return Container(
        height: 72,
        decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(36)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(widget.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: widget.color.withValues(alpha: 0.85))),
            Positioned(
              left: _drag.clamp(0, max),
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx),
                onHorizontalDragEnd: (_) async {
                  if (_drag >= max * 0.85) await widget.onComplete();
                  setState(() => _drag = 0);
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
