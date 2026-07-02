import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velo_core/velo_core.dart';

final apiProvider = Provider((ref) => ApiClient());

final authRepoProvider = Provider((ref) => AuthRepository(ref.watch(apiProvider)));

final authStateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.watch(authRepoProvider).me();
});

final riderProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.watch(apiProvider).get('/rider/profile');
  return res.data as Map<String, dynamic>;
});

final riderStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.watch(apiProvider).get('/rider/stats');
  return res.data as Map<String, dynamic>;
});

final assignmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(apiProvider).get('/rider/assignments');
  final list = (res.data['data'] as List?) ?? [];
  return list.cast<Map<String, dynamic>>();
});

final riderOrdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, filter) async {
  final res = await ref.watch(apiProvider).get('/rider/orders', query: {'filter': filter});
  final list = (res.data['data'] as List?) ?? [];
  return list.cast<Map<String, dynamic>>();
});

final riderWalletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.watch(apiProvider).get('/rider/wallet');
  return res.data['data'] as Map<String, dynamic>;
});

final riderSettlementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(apiProvider).get('/rider/settlements');
  final list = (res.data['data'] as List?) ?? [];
  return list.cast<Map<String, dynamic>>();
});
