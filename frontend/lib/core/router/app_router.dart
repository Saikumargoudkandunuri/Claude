import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pending_approval_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/assignments/presentation/assignment_management_screen.dart';
import '../../features/dashboard/presentation/admin_dashboard.dart';
import '../../features/dashboard/presentation/designer_dashboard.dart';
import '../../features/dashboard/presentation/supervisor_dashboard.dart';
import '../../features/dashboard/presentation/worker_dashboard.dart';
import '../../features/drawings/presentation/pdf_viewer_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/payments/presentation/payments_overview_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/projects/presentation/project_detail_screen.dart';
import '../../features/projects/presentation/project_form_screen.dart';
import '../../features/projects/presentation/projects_list_screen.dart';
import '../../features/reports/presentation/all_reports_screen.dart';
import '../../features/reports/presentation/reports_home_screen.dart';
import '../../features/tasks/presentation/task_panel_screen.dart';
import '../../features/users/presentation/approvals_screen.dart';
import '../../features/users/presentation/workers_screen.dart';
import '../../shared/navigation/back_guard.dart';
import '../widgets/role_scaffold.dart';

/// GoRouter wired to auth state with role-based redirects and shells.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';

      if (auth.isLoading) return loc == '/splash' ? null : '/splash';

      final user = auth.user;
      if (user == null) return onAuthPage ? null : '/login';

      if (user.status == 'pending') return '/pending';
      if (user.status == 'rejected' || user.status == 'disabled') {
        return onAuthPage ? null : '/login';
      }

      // Approved: keep out of splash/auth/pending; land on role home.
      if (onAuthPage || loc == '/splash' || loc == '/pending') {
        return _homeForRole(user.role);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/pending', builder: (_, __) => const PendingApprovalScreen()),

      // Full-screen routes (no bottom nav) — wrapped in BackGuard so the
      // system/AppBar back never closes the app from an inner screen.
      GoRoute(
        path: '/viewer',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? const {};
          return BackGuard(
            child: PdfViewerScreen(
              url: extra['url']?.toString() ?? '',
              name: extra['name']?.toString() ?? 'Drawing',
            ),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const BackGuard(child: ProfileScreen()),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const BackGuard(child: SettingsScreen()),
      ),

      // ===== Admin shell =====
      ShellRoute(
        builder: (_, state, child) => RoleScaffold(
          location: state.uri.toString(),
          destinations: _adminTabs,
          child: child,
        ),
        routes: [
          GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
          GoRoute(
            path: '/admin/projects',
            builder: (_, __) => const ProjectsListScreen(basePath: '/admin'),
          ),
          GoRoute(
            path: '/admin/approvals',
            builder: (_, __) => const ApprovalsScreen(),
          ),
          GoRoute(
            path: '/admin/assignments',
            builder: (_, __) => const AssignmentManagementScreen(),
          ),
          GoRoute(
            path: '/admin/workers',
            builder: (_, __) => const WorkersScreen(),
          ),
          GoRoute(
            path: '/admin/tasks',
            builder: (_, __) => const TaskPanelScreen(),
          ),
          GoRoute(
            path: '/admin/all-reports',
            builder: (_, __) => const AllReportsScreen(),
          ),
          GoRoute(
            path: '/admin/payments',
            builder: (_, __) => const PaymentsOverviewScreen(),
          ),
          GoRoute(
            path: '/admin/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/projects/new',
        builder: (_, __) => const BackGuard(child: ProjectFormScreen()),
      ),
      GoRoute(
        path: '/admin/projects/:id',
        builder: (_, s) => BackGuard(
            child: ProjectDetailScreen(projectId: s.pathParameters['id']!)),
      ),

      // ===== Supervisor shell =====
      ShellRoute(
        builder: (_, state, child) => RoleScaffold(
          location: state.uri.toString(),
          destinations: _supervisorTabs,
          child: child,
        ),
        routes: [
          GoRoute(
              path: '/supervisor',
              builder: (_, __) => const SupervisorDashboard()),
          GoRoute(
            path: '/supervisor/projects',
            builder: (_, __) =>
                const ProjectsListScreen(basePath: '/supervisor'),
          ),
          GoRoute(
            path: '/supervisor/reports',
            builder: (_, __) => const ReportsHomeScreen(),
          ),
          GoRoute(
            path: '/supervisor/all-reports',
            builder: (_, __) => const AllReportsScreen(),
          ),
          GoRoute(
            path: '/supervisor/assignments',
            builder: (_, __) => const AssignmentManagementScreen(),
          ),
          GoRoute(
            path: '/supervisor/workers',
            builder: (_, __) => const WorkersScreen(),
          ),
          GoRoute(
            path: '/supervisor/tasks',
            builder: (_, __) => const TaskPanelScreen(),
          ),
          GoRoute(
            path: '/supervisor/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/supervisor/projects/:id',
        builder: (_, s) => BackGuard(
            child: ProjectDetailScreen(projectId: s.pathParameters['id']!)),
      ),

      // ===== Designer shell =====
      ShellRoute(
        builder: (_, state, child) => RoleScaffold(
          location: state.uri.toString(),
          destinations: _designerTabs,
          child: child,
        ),
        routes: [
          GoRoute(
              path: '/designer', builder: (_, __) => const DesignerDashboard()),
          GoRoute(
            path: '/designer/projects',
            builder: (_, __) => const ProjectsListScreen(basePath: '/designer'),
          ),
          GoRoute(
            path: '/designer/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/designer/projects/:id',
        builder: (_, s) => BackGuard(
            child: ProjectDetailScreen(projectId: s.pathParameters['id']!)),
      ),

      // ===== Worker shell =====
      ShellRoute(
        builder: (_, state, child) => RoleScaffold(
          location: state.uri.toString(),
          destinations: _workerTabs,
          child: child,
        ),
        routes: [
          GoRoute(path: '/worker', builder: (_, __) => const WorkerDashboard()),
          GoRoute(
            path: '/worker/reports',
            builder: (_, __) => const ReportsHomeScreen(),
          ),
          GoRoute(
            path: '/worker/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/worker/sites/:id',
        builder: (_, s) => BackGuard(
            child: ProjectDetailScreen(projectId: s.pathParameters['id']!)),
      ),
    ],
  );
});

String _homeForRole(String? role) {
  switch (role) {
    case 'admin':
      return '/admin';
    case 'supervisor':
      return '/supervisor';
    case 'designer':
      return '/designer';
    case 'worker':
      return '/worker';
    default:
      return '/login';
  }
}

const _adminTabs = [
  RoleDestination(
    label: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    route: '/admin',
  ),
  RoleDestination(
    label: 'Projects',
    icon: Icons.home_work_outlined,
    selectedIcon: Icons.home_work,
    route: '/admin/projects',
  ),
  RoleDestination(
    label: 'Workers',
    icon: Icons.engineering_outlined,
    selectedIcon: Icons.engineering,
    route: '/admin/workers',
  ),
  RoleDestination(
    label: 'Alerts',
    icon: Icons.notifications_none,
    selectedIcon: Icons.notifications,
    route: '/admin/notifications',
  ),
];

const _supervisorTabs = [
  RoleDestination(
    label: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    route: '/supervisor',
  ),
  RoleDestination(
    label: 'Projects',
    icon: Icons.home_work_outlined,
    selectedIcon: Icons.home_work,
    route: '/supervisor/projects',
  ),
  RoleDestination(
    label: 'Reports',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
    route: '/supervisor/reports',
  ),
  RoleDestination(
    label: 'Alerts',
    icon: Icons.notifications_none,
    selectedIcon: Icons.notifications,
    route: '/supervisor/notifications',
  ),
];

const _designerTabs = [
  RoleDestination(
    label: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    route: '/designer',
  ),
  RoleDestination(
    label: 'Projects',
    icon: Icons.home_work_outlined,
    selectedIcon: Icons.home_work,
    route: '/designer/projects',
  ),
  RoleDestination(
    label: 'Alerts',
    icon: Icons.notifications_none,
    selectedIcon: Icons.notifications,
    route: '/designer/notifications',
  ),
];

const _workerTabs = [
  RoleDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    route: '/worker',
  ),
  RoleDestination(
    label: 'Reports',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
    route: '/worker/reports',
  ),
  RoleDestination(
    label: 'Alerts',
    icon: Icons.notifications_none,
    selectedIcon: Icons.notifications,
    route: '/worker/notifications',
  ),
];
