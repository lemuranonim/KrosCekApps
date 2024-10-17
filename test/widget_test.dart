import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/main.dart';
import 'package:mockito/mockito.dart'; // Import mockito
import 'package:shared_preferences/shared_preferences.dart';

// Mock class for SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Mocking SharedPreferences
    final mockPrefs = MockSharedPreferences();

    // Simulate that the user is not logged in
    when(mockPrefs.getBool('isLoggedIn')).thenReturn(false);

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(showLoginScreen: true));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
