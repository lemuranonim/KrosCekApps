import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kroscek/screens/admin/config_crud.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Admin
import 'screens/admin/absensi_dashboard.dart';
import 'screens/admin/account_management.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/aktivitas_dashboard.dart';
import 'screens/admin/filter_regions.dart';
import 'screens/admin/regions_dashboard.dart';
// QA
import 'screens/qa/qa_screen.dart';
// Login
import 'screens/login_screen.dart';
// Splash
import 'screens/splash_screen.dart';
// Flagging Graph
import 'screens/admin/flagging_graph_page.dart';
// Workload Map
// import 'screens/admin/workload_map_screen.dart';
// Audit Dashboard
import 'screens/admin/audit_dashboard.dart';
// Notification Management
import 'screens/admin/notifications_management.dart';
// Edit Field Screen
import 'screens/qa/edit_field_screen.dart';

// New Refactor Screens
import 'screens/inspection/form_vegetative.dart';
import 'screens/inspection/form_generative_1.dart';
import 'screens/inspection/form_generative_2.dart';
import 'screens/inspection/form_generative_3.dart';
import 'screens/inspection/form_pre_harvest.dart';
import 'screens/inspection/form_harvest.dart';
import 'screens/inspection/mass_inspect_screen.dart';
import 'screens/attendance/check_in_screen.dart';
import 'screens/attendance/check_out_screen.dart';
import 'screens/coverage/coverage_screen.dart';
import 'screens/qa/detailed_map_screen.dart';
import 'screens/settings/user_settings_screen.dart';
import 'screens/settings/qa_mapping_screen.dart';
import '../../services/session_manager.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
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
      path: '/qa',
      builder: (context, state) => const QAScreen(),
    ),
    GoRoute(
      path: '/qa/settings',
      builder: (context, state) => const UserSettingsScreen(),
    ),
    GoRoute(
      path: '/qa/settings/mapping',
      builder: (context, state) => const QaMappingScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
    ),
    GoRoute(
      path: '/accounts',
      builder: (context, state) => const AccountManagement(),
    ),
    GoRoute(
      path: '/regions',
      builder: (context, state) => const RegionsDashboard(),
    ),
    GoRoute(
      path: '/absensi',
      builder: (context, state) => const AbsensiDashboard(),
    ),
    GoRoute(
      path: '/aktivitas',
      builder: (context, state) => const AktivitasDashboard(),
    ),
    GoRoute(
      path: '/config',
      builder: (context, state) => const CrudPage(),
    ),
    GoRoute(
      path: '/filter',
      builder: (context, state) => const FilterRegionsScreen(),
    ),
    // GoRoute(
    //   path: '/workload_map',
    //   builder: (context, state) => const WorkloadMapScreen(),
    // ),
    GoRoute(
      path: '/detailed_map',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return DetailedMapScreen(
          initialRegion: extra?['region'],
          initialDistrict: extra?['district'],
          initialSeason: extra?['season'],
        );
      },
    ),
    GoRoute(
      path: '/audit_dashboard',
      builder: (context, state) => const AuditDashboard(),
    ),
    GoRoute(
      path: '/flagging_graph',
      builder: (context, state) => const FlaggingGraphPage(),
    ),
    GoRoute(
      path: '/notifications_management',
      builder: (context, state) => const NotificationsManagementScreen(),
    ),
    // --- NEW INSPECTION ROUTES ---
    GoRoute(
      path: '/inspect/vegetative/:fieldNumber',
      builder: (context, state) => FormVegetative(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect/generative_1/:fieldNumber',
      builder: (context, state) => FormGenerative1(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect/generative_2/:fieldNumber',
      builder: (context, state) => FormGenerative2(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect/generative_3/:fieldNumber',
      builder: (context, state) => FormGenerative3(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect/pre_harvest/:fieldNumber',
      builder: (context, state) => FormPreHarvest(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect/harvest/:fieldNumber',
      builder: (context, state) => FormHarvest(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect/mass',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return MassInspectScreen(
          fieldNumbers: extra?['fieldNumbers'] as List<String>? ?? [],
          targetPhase: extra?['phase'] as String? ?? 'vegetative',
        );
      },
    ),
    GoRoute(
      path: '/edit-field',
      builder: (context, state) {
        final fieldData = state.extra as Map<String, dynamic>;
        return EditFieldScreen(fieldData: fieldData);
      },
    ),

    // --- NEW ATTENDANCE ROUTES ---
    GoRoute(
      path: '/checkin',
      builder: (context, state) => const CheckInScreen(),
    ),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckOutScreen(),
    ),
    GoRoute(
      path: '/coverage',
      builder: (context, state) => const CoverageScreen(),
    ),
  ],
  redirect: (context, state) async {
    if (state.matchedLocation == '/splash') return null;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final session      = await SessionManager.instance.getActiveSession();

    final isLoggedIn = supabaseUser != null && session != null;
    final userRole   = session?.role;

    if (!isLoggedIn && state.matchedLocation != '/login') {
      return '/login';
    }

    // PI role: jika somehow masuk /qa, redirect ke /pi
    if (isLoggedIn && userRole?.toLowerCase() == 'pi' &&
        state.matchedLocation == '/qa') {
      return '/pi';
    }

    return null;
  },
);