import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../services/location_tracker.dart';

final locationTrackerProvider = Provider<LocationTracker>((ref) {
  final tracker = LocationTracker(ref.watch(apiProvider));
  ref.onDispose(tracker.dispose);
  return tracker;
});

class RiderShell extends ConsumerWidget {
  const RiderShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(riderProfileProvider, (prev, next) {
      next.whenData((data) {
        final online = data['profile']?['is_online'] == true;
        final tracker = ref.read(locationTrackerProvider);
        if (online) {
          tracker.start();
        } else {
          tracker.stop();
        }
      });
    });

    // Ensure provider is watched so listener runs on first load.
    ref.watch(riderProfileProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index(context),
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/stats');
            case 2:
              context.go('/wallet');
            case 3:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  int _index(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/stats')) return 1;
    if (loc.startsWith('/wallet')) return 2;
    if (loc.startsWith('/profile')) return 3;
    return 0;
  }
}
