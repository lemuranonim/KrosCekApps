import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/main.dart'; // MyApp masih di sini
import 'package:kroscek/screens/splash_screen.dart';
import 'package:kroscek/screens/login_screen.dart';
import 'package:kroscek/screens/qa/qa_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import file widget yang baru
import 'package:kroscek/widgets/no_internet_app.dart';
import 'package:kroscek/widgets/permission_screen.dart';

// Mock class for SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  final mockPrefs = MockSharedPreferences();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Initialize mock shared preferences
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Test splash screen appears first', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const MyApp());

    // Verify splash screen is shown initially
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('Test navigation flow when not logged in', (WidgetTester tester) async {
    // Mock not logged in state
    when(mockPrefs.getBool('isLoggedIn')).thenReturn(false);

    await tester.pumpWidget(const MyApp());

    // Wait for splash screen to complete
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify login screen appears
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Test navigation flow when logged in as user', (WidgetTester tester) async {
    // Mock logged in state
    when(mockPrefs.getBool('isLoggedIn')).thenReturn(true);
    when(mockPrefs.getString('userRole')).thenReturn('user');

    await tester.pumpWidget(const MyApp());

    // Wait for splash screen to complete
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify home screen appears
    expect(find.byType(QaScreen), findsOneWidget);
  });

  testWidgets('Test NoInternetApp widget', (WidgetTester tester) async {
    await tester.pumpWidget(const NoInternetApp());

    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.text('Tidak ada koneksi internet. Harap periksa koneksi Anda.'), findsOneWidget);
  });

  testWidgets('Test PermissionScreen widget', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PermissionScreen(),
    ));

    expect(find.text('Permissions'), findsOneWidget);
    expect(find.text('Izin telah diperiksa!'), findsOneWidget);
  });
}