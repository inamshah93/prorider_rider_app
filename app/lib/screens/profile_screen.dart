import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:velo_core/velo_core.dart';

import '../providers/app_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _toggleOnline(WidgetRef ref, bool value) async {
    await ref.read(apiProvider).put('/rider/online-status', data: {'is_online': value});
    ref.invalidate(riderProfileProvider);
  }

  Future<void> _logout(WidgetRef ref, BuildContext context) async {
    await ref.read(authRepoProvider).logout();
    ref.invalidate(authStateProvider);
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(riderProfileProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        data: (data) {
          final user = data['user'] as Map<String, dynamic>? ?? {};
          final rider = data['profile'] as Map<String, dynamic>? ?? {};
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final online = rider['is_online'] == true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          (user['name']?.toString() ?? 'R').substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 28, color: AppTheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['name']?.toString() ?? '—', style: Theme.of(context).textTheme.titleLarge),
                            Text(user['email']?.toString() ?? '', style: TextStyle(color: colors.onSurfaceVariant)),
                            Text(user['phone']?.toString() ?? '', style: TextStyle(color: colors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: const Text('Go online'),
                  subtitle: Text(online ? 'Receiving new assignments' : 'You are offline'),
                  value: online,
                  activeTrackColor: AppTheme.success.withValues(alpha: 0.5),
                  activeThumbColor: AppTheme.success,
                  onChanged: (v) => _toggleOnline(ref, v),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: const Text('Cash in hand'),
                      trailing: Text(
                        '₨ ${rider['cash_in_hand'] ?? '0'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      onTap: () => context.go('/wallet'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.location_city_outlined),
                      title: const Text('Assigned city'),
                      trailing: Text(rider['assigned_city']?.toString() ?? '—'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        rider['documents_verified'] == true ? Icons.verified : Icons.pending_outlined,
                        color: rider['documents_verified'] == true ? AppTheme.success : Colors.orange,
                      ),
                      title: const Text('Documents'),
                      trailing: Text(
                        rider['documents_verified'] == true ? 'Verified' : 'Pending',
                        style: TextStyle(
                          color: rider['documents_verified'] == true ? AppTheme.success : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Order summary', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(label: 'Total', value: '${stats['all'] ?? 0}'),
                  _SummaryChip(label: 'Delivered', value: '${stats['delivered'] ?? 0}', color: AppTheme.success),
                  _SummaryChip(label: 'Pending', value: '${stats['pending'] ?? 0}', color: Colors.orange),
                  _SummaryChip(label: 'In Process', value: '${stats['in_process'] ?? 0}', color: Colors.blue),
                  _SummaryChip(label: 'Returned', value: '${stats['returned'] ?? 0}', color: Colors.red),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _logout(ref, context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value, this.color = AppTheme.primary});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Text(value, style: TextStyle(color: color, fontSize: 12))),
      label: Text(label),
    );
  }
}
