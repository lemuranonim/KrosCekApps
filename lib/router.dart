import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kroscek/screens/admin/config_crud.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Admin
import 'screens/admin/absensi_dashboard.dart';
import 'screens/admin/account_management.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/aktivitas_dashboard.dart';
import 'screens/admin/filter_regions.dart';
import 'screens/admin/regions_dashboard.dart';
// QA
import 'screens/qa/qa_screen.dart';
// HSP
import 'screens/hsp/hsp_screen.dart';
// Login
import 'screens/login_screen.dart';
// PSP
import 'screens/psp/psp_screen.dart';
// PSP HSP
import 'screens/psphsp/psp_hsp_screen.dart';
// Splash
import 'screens/splash_screen.dart';
// Audit Graph
import 'screens/admin/audit_graph_page.dart';
// Workload Map
import 'screens/admin/workload_map_screen.dart';
// Audit Dashboard
import 'screens/admin/audit_dashboard.dart';
// Notification Management
import 'screens/admin/notifications_management.dart';

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
      builder: (context, state) => const QaScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
    ),
    GoRoute(
      path: '/psp',
      builder: (context, state) => const PspScreen(),
    ),
    GoRoute(
      path: '/hsp',
      builder: (context, state) => const HspScreen(),
    ),
    // PSP HSP
    GoRoute(
      path: '/psphsp',
      builder: (context, state) => const PspHspScreen(),
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
    GoRoute(
      path: '/audit_graph',
      builder: (context, state) => const AuditGraphPage(),
    ),
    //workload map
    GoRoute(
      path: '/workload_map',
      builder: (context, state) => const WorkloadMapScreen(),
    ),
    // Audit Dashboard
    GoRoute(
      path: '/audit_dashboard',
      builder: (context, state) => const AuditDashboard(),
    ),
    // Notification Management
    GoRoute(
      path: '/notifications_management',
      builder: (context, state) => const NotificationsManagementScreen(),
    ),
  ],
  redirect: (context, state) async {
    // Skip authentication check for splash screen
    if (state.matchedLocation == '/splash') {
      return null;
    }

    // Check login status for other routes
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? userRole = prefs.getString('userRole');

    // If not logged in, redirect to login
    if (!isLoggedIn && state.matchedLocation != '/login') {
      return '/login';
    }

    // If logged in as admin and trying to access home, redirect to admin dashboard
    if (isLoggedIn && userRole == 'admin' && state.matchedLocation == '/qa') {
      return '/admin';
    }

    return null;
  },
);
