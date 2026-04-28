import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers.dart';
import 'screens.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const admin = '/admin';
  static const users = '/users';
  static const createUser = '/users/create';
  static const clinics = '/clinics';
  static const capture = '/capture';
  static const review = '/review';
  static const mine = '/mine';
}

final routerProvider = Provider<GoRouter>((ref) {
  final profileAsync = ref.watch(currentProfileProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final user = Supabase.instance.client.auth.currentUser;

      final isLogin = loc == AppRoutes.login;
      final isSplash = loc == AppRoutes.splash;

      // No session: never stay stuck on splash/loading.
      if (user == null) {
        return isLogin ? null : AppRoutes.login;
      }

      // Session exists but profile is still loading: allow splash only temporarily.
      if (profileAsync.isLoading) {
        return isSplash ? null : AppRoutes.splash;
      }

      // Session exists but profile failed/missing: force login.
      final profile = profileAsync.valueOrNull;
      if (profile == null) {
        return isLogin ? null : AppRoutes.login;
      }

      // Logged in: leave login/splash.
      if (isLogin || isSplash) {
        return profile.isAdmin ? AppRoutes.admin : AppRoutes.capture;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.admin, builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: AppRoutes.users, builder: (_, __) => const UsersManagementScreen()),
      GoRoute(path: AppRoutes.createUser, builder: (_, __) => const CreateUserScreen()),
      GoRoute(path: AppRoutes.clinics, builder: (_, __) => const ClinicsListScreen(mineOnly: false)),
      GoRoute(path: AppRoutes.mine, builder: (_, __) => const ClinicsListScreen(mineOnly: true)),
      GoRoute(path: AppRoutes.capture, builder: (_, __) => const CaptureScreen()),
      GoRoute(path: AppRoutes.review, builder: (_, state) => OcrReviewScreen(extra: state.extra as CapturePayload)),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(currentProfileProvider, (_, __) => notifyListeners());
    ref.listen(authChangesProvider, (_, __) => notifyListeners());
  }
}
