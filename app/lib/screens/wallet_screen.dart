import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velo_core/velo_core.dart';

import '../providers/app_providers.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(riderWalletProvider);
    final settlements = ref.watch(riderSettlementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(riderWalletProvider);
          ref.invalidate(riderSettlementsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            wallet.when(
              data: (w) => Column(
                children: [
                  _MoneyCard(
                    label: 'Remaining to pay company',
                    amount: w['remaining_to_pay'],
                    color: Colors.orange,
                    large: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _MoneyCard(label: 'Total collected', amount: w['total_collected'], color: AppTheme.primary)),
                      const SizedBox(width: 8),
                      Expanded(child: _MoneyCard(label: 'Commission earned', amount: w['total_commission_earned'], color: AppTheme.success)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MoneyCard(label: 'Already paid to company', amount: w['total_settled'], color: Colors.blueGrey),
                  if (w['commission_rate'] != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Your commission rate: ${((JsonNum.parseDouble(w['commission_rate']) ?? 0) * 100).toStringAsFixed(1)}% of delivery charge',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (w['recent_entries'] is List && (w['recent_entries'] as List).isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Earnings breakdown', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...(w['recent_entries'] as List).map((e) {
                      final entry = e as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text('${entry['entry_type'] ?? 'entry'}'.replaceAll('_', ' ')),
                          subtitle: Text(entry['reference']?.toString() ?? entry['notes']?.toString() ?? ''),
                          trailing: Text('₨ ${(JsonNum.parseDouble(entry['amount']) ?? 0).toStringAsFixed(0)}'),
                        ),
                      );
                    }),
                  ],
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load wallet: $e'),
            ),
            const SizedBox(height: 24),
            Text('Payment history', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            settlements.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No payments recorded yet')),
                  );
                }
                return Column(
                  children: items.map((s) => _SettlementTile(settlement: s)).toList(),
                );
              },
              loading: () => const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.label, required this.amount, required this.color, this.large = false});

  final String label;
  final dynamic amount;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              '₨ ${(JsonNum.parseDouble(amount) ?? 0).toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: large ? 28 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({required this.settlement});

  final Map<String, dynamic> settlement;

  @override
  Widget build(BuildContext context) {
    final proofUrl = settlement['proof_url']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('₨ ${(JsonNum.parseDouble(settlement['amount']) ?? 0).toStringAsFixed(0)}'),
        subtitle: Text(settlement['notes']?.toString() ?? settlement['created_at']?.toString() ?? ''),
        trailing: proofUrl != null && proofUrl.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.image_outlined),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(child: Image.network(proofUrl, fit: BoxFit.contain)),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
