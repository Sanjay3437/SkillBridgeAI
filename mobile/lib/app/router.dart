import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analysis/presentation/analysis_detail_screen.dart';
import '../features/analysis/presentation/new_analysis_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/jobs/presentation/job_detail_screen.dart';
import '../features/jobs/presentation/jobs_screen.dart';
import '../features/jobs/presentation/new_job_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/resume/presentation/resume_detail_screen.dart';
import '../features/resume/presentation/resumes_screen.dart';
import '../features/roadmap/presentation/roadmap_screen.dart';
import '../features/shell/presentation/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final notifier = _RouterRefresh();
  ref.listen<AuthState>(authControllerProvider, (_, _) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final onAuthScreen = location == '/login' || location == '/register';

      if (!auth.isResolved) {
        return location == '/splash' ? null : '/splash';
      }
      if (!auth.isAuthenticated) {
        return onAuthScreen ? null : '/login';
      }
      if (onAuthScreen || location == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/resumes',
                builder: (context, state) => const ResumesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/jobs',
                builder: (context, state) => const JobsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/resumes/:id',
        builder: (context, state) => ResumeDetailScreen(resumeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/jobs/new',
        builder: (context, state) => const NewJobScreen(),
      ),
      GoRoute(
        path: '/jobs/:id',
        builder: (context, state) => JobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/analyses/new',
        builder: (context, state) => NewAnalysisScreen(
          initialResumeId: state.uri.queryParameters['resumeId'],
          initialJobId: state.uri.queryParameters['jobId'],
        ),
      ),
      GoRoute(
        path: '/analyses/:id',
        builder: (context, state) => AnalysisDetailScreen(analysisId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/analyses/:id/roadmap',
        builder: (context, state) => RoadmapScreen(analysisId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
