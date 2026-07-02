import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velo_core/velo_core.dart';

import '../providers/app_providers.dart';
import '../widgets/order_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<int> _selected = {};

  bool _canPickUp(Map<String, dynamic> order) {
    final status = order['order_status']?.toString() ?? '';
    return status == 'ready_to_ship' || status == 'dispatched';
  }

  double? _commissionRate(Map<String, dynamic>? profileData) {
    final p = profileData?['profile'] as Map<String, dynamic>?;
    if (p == null) return null;
    final rate = p['effective_commission_rate'] ?? p['commission_rate'];
    if (rate == null) return null;
    return JsonNum.parseDouble(rate);
  }

  Future<void> _batchPickUp() async {
    if (_selected.isEmpty) return;
    try {
      await ref.read(apiProvider).post('/rider/orders/batch-picked-up', data: {
        'order_ids': _selected.toList(),
      });
      if (!mounted) return;
      setState(() => _selected.clear());
      ref.invalidate(assignmentsProvider);
      ref.invalidate(riderProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected orders marked as picked up')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pickup failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignments = ref.watch(assignmentsProvider);
    final profile = ref.watch(riderProfileProvider);
    final commissionRate = profile.valueOrNull != null ? _commissionRate(profile.valueOrNull) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          profile.when(
            data: (p) {
              final online = p['profile']?['is_online'] == true;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(Icons.circle, size: 12, color: online ? AppTheme.success : Colors.grey),
                  label: Text(online ? 'Online' : 'Offline'),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: _selected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _batchPickUp,
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text('Pick up selected (${_selected.length})'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(assignmentsProvider);
          ref.invalidate(riderProfileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            profile.when(
              data: (p) {
                final stats = p['stats'] as Map<String, dynamic>? ?? {};
                return Row(
                  children: [
                    _StatTile(label: 'Active', value: '${stats['in_process'] ?? 0}', color: Colors.blue),
                    const SizedBox(width: 8),
                    _StatTile(label: 'Pending', value: '${stats['pending'] ?? 0}', color: Colors.orange),
                    const SizedBox(width: 8),
                    _StatTile(label: 'Delivered', value: '${stats['delivered'] ?? 0}', color: AppTheme.success),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            Text('Active assignments', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            assignments.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.delivery_dining, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No active orders',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pull to refresh when new orders arrive',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: orders.map((o) {
                    final id = JsonNum.parseInt(o['id']) ?? 0;
                    final pickable = _canPickUp(o);
                    return OrderCard(
                      order: o,
                      commissionRate: commissionRate,
                      selectable: pickable,
                      selected: _selected.contains(id),
                      onSelected: pickable
                          ? (v) => setState(() {
                                if (v) {
                                  _selected.add(id);
                                } else {
                                  _selected.remove(id);
                                }
                              })
                          : null,
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, _) => Text('Failed to load: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
