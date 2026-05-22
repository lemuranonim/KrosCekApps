import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Admin
// import 'screens/admin/admin_dashboard.dart';
// QA
import 'screens/qa/qa_screen.dart';
import 'screens/module_select_screen.dart';
import 'screens/got_fet/got_fet_screen.dart';
import 'screens/got_fet/got_fet_settings_screen.dart';
// Login
import 'screens/login_screen.dart';
// Splash
import 'screens/splash_screen.dart';
// Workload Map
// import 'screens/admin/workload_map_screen.dart';
// Edit Field Screen
import 'screens/qa/edit_field_screen.dart';
// SC
import 'screens/inspection/form_vegetative_sc.dart';
import 'screens/inspection/form_vegetative_psp.dart';
import 'screens/inspection/form_generative_psp.dart';
import 'screens/inspection/form_harvest_psp.dart';
import 'screens/inspection/form_generative_1_sc.dart';
import 'screens/inspection/form_generative_2_sc.dart';
import 'screens/inspection/form_generative_3_sc.dart';
import 'screens/inspection/form_generative_4_sc.dart';
import 'screens/inspection/form_generative_5_sc.dart';
import 'screens/inspection/form_pre_harvest_sc.dart';
import 'screens/inspection/form_harvest_sc.dart';

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
import 'screens/qa/detasseling_map_screen.dart';
import 'screens/qa/detailed_map_screen.dart';
import 'screens/settings/user_settings_screen.dart';
import 'screens/settings/qa_mapping_screen.dart';
import '../../services/session_manager.dart';
import 'providers/detasseling_plan_provider.dart'
    show canAccessDetasselingMapForRole;

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

const _adminOnlyRoutes = {
  '/admin',
};

const _operationalWriteRoles = {
  'admin',
  'fi',
  'spv',
  'qa',
  'manager',
  'dev',
};

bool _isAdminRole(String? role) => role?.toLowerCase() == 'admin';
bool _isGuestRole(String? role) => role?.toLowerCase() == 'guest';
bool _canWriteOperational(String? role) =>
    _operationalWriteRoles.contains(role?.toLowerCase());
Future<String> _homeForActiveSession() async {
  return await SessionManager.instance.getSelectedModuleRoute() ??
      '/module-select';
}
bool _isInspectionRoute(String path) =>
    path.startsWith('/inspect/') ||
    path.startsWith('/inspect_sc/') ||
    path.startsWith('/inspect_psp/');
bool _isOperationalWriteRoute(String path) =>
    _isInspectionRoute(path) ||
    path == '/inspect/mass' ||
    path == '/edit-field' ||
    path == '/checkin' ||
    path == '/checkout';

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
      path: '/module-select',
      builder: (context, state) => const ModuleSelectScreen(),
    ),
    GoRoute(
      path: '/qa',
      builder: (context, state) => const QAScreen(),
    ),
    GoRoute(
      path: '/got-fet',
      builder: (context, state) => const GotFetScreen(),
    ),
    GoRoute(
      path: '/got-fet/settings',
      builder: (context, state) => const GotFetSettingsScreen(),
    ),
    GoRoute(
      path: '/qa/settings',
      builder: (context, state) => const UserSettingsScreen(),
    ),
    GoRoute(
      path: '/qa/settings/mapping',
      builder: (context, state) => const QaMappingScreen(),
    ),
    // GoRoute(
    //   path: '/admin',
    //   builder: (context, state) => const AdminDashboard(),
    // ),
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
      path: '/inspect_psp/vegetative/:fieldNumber',
      builder: (context, state) => FormVegetativePSP(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect_psp/generative/:fieldNumber',
      builder: (context, state) => FormGenerativePSP(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect_psp/harvest/:fieldNumber',
      builder: (context, state) => FormHarvestPSP(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
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
    GoRoute(
      path: '/detasseling-map',
      builder: (context, state) => const DetasselingMapScreen(),
    ),

    // --- SWEET CORN (SC) INSPECTION ROUTES ---
    GoRoute(
      path: '/inspect_sc/vegetative/:fieldNumber',
      builder: (context, state) => FormVegetativeSC(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect_sc/generative_1/:fieldNumber',
      builder: (context, state) => FormGenerative1SC(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect_sc/generative_2/:fieldNumber',
      builder: (context, state) => FormGenerative2SC(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect_sc/generative_3/:fieldNumber',
      builder: (context, state) => FormGenerative3SC(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect_sc/generative_4/:fieldNumber',
      builder: (context, state) => FormGenerative4SC(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect_sc/generative_5/:fieldNumber',
      builder: (context, state) => FormGenerative5SC(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect_sc/pre_harvest/:fieldNumber',
      builder: (context, state) => FormPreHarvestSC(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
    GoRoute(
      path: '/inspect_sc/harvest/:fieldNumber',
      builder: (context, state) => FormHarvestSC(
        fieldNumber: state.pathParameters['fieldNumber']!,
      ),
    ),
  ],
  redirect: (context, state) async {
    final path = state.uri.path;
    if (path == '/splash') return null;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final session = await SessionManager.instance.getActiveSession();

    final isLoggedIn = supabaseUser != null && session != null;
    final userRole = session?.role;
    final userAction = session?.action;

    if (!isLoggedIn && path != '/login') {
      return '/login';
    }

    if (isLoggedIn && path == '/login') {
      return await _homeForActiveSession();
    }

    if (!isLoggedIn) return null;

    if (_adminOnlyRoutes.contains(path) && !_isAdminRole(userRole)) {
      return await _homeForActiveSession();
    }

    if (_isOperationalWriteRoute(path) && !_canWriteOperational(userRole)) {
      return await _homeForActiveSession();
    }

    if ((path == '/coverage' || path == '/qa/settings/mapping') &&
        _isGuestRole(userRole)) {
      return await _homeForActiveSession();
    }

    if (path == '/detasseling-map' &&
        !canAccessDetasselingMapForRole(
          role: userRole,
          action: userAction,
          name: session.name,
        )) {
      return await _homeForActiveSession();
    }

    return null;
  },
);
