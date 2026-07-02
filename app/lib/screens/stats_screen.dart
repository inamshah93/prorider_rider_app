import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../widgets/order_card.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _filters = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('in_process', 'In Process'),
    ('delivered', 'Delivered'),
    ('returned', 'Returned'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(riderStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats & Orders'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: stats.when(
            data: (s) => _filters
                .map((f) => Tab(text: '${f.$2} (${s[f.$1] ?? 0})'))
                .toList(),
            loading: () => _filters.map((f) => Tab(text: f.$2)).toList(),
            error: (_, __) => _filters.map((f) => Tab(text: f.$2)).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _filters.map((f) => _OrderListTab(filter: f.$1)).toList(),
      ),
    );
  }
}

class _OrderListTab extends ConsumerWidget {
  const _OrderListTab({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(riderOrdersProvider(filter));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(riderOrdersProvider(filter));
        ref.invalidate(riderStatsProvider);
      },
      child: orders.when(
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No orders in this category')),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) => OrderCard(order: list[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
