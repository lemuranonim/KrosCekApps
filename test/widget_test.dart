import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';

// Mock class for SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  final mockPrefs = MockSharedPreferences();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    when(mockPrefs.getBool('isLoggedIn')).thenReturn(false);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MyApp(showLoginScreen: true));

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Login screen appears when user is not logged in', (WidgetTester tester) async {
    when(mockPrefs.getBool('isLoggedIn')).thenReturn(false);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MyApp(showLoginScreen: true));

    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
