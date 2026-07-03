import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:velo_core/velo_core.dart';

import 'providers/app_providers.dart';
import 'screens/documents_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/wallet_screen.dart';
import 'widgets/rider_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initPushRegistration();
  runApp(const ProviderScope(child: RiderApp()));
}

class RiderApp extends ConsumerWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.light();
    final router = GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final auth = ref.read(authStateProvider);
        final user = auth.valueOrNull;
        final loggingIn = state.matchedLocation == '/login';
        if (auth.isLoading) return null;
        if (user == null && !loggingIn) return '/login';
        if (user != null && loggingIn) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        ShellRoute(
          builder: (_, __, child) => RiderShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
            GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
            GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
            GoRoute(
              path: '/orders/:id',
              builder: (_, state) => OrderDetailScreen(
                orderId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Velo Rider',
      theme: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
          headlineMedium: theme.textTheme.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      routerConfig: router,
    );
  }
}
