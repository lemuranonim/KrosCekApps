import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/supabase_auth_service.dart';
import 'package:kroscek/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Krisna account always resolves to QA SPV', () {
    expect(
      effectiveAppUserRole(
        email: ' K.BagusAndrian@GMAIL.COM ',
        role: 'MANAGER',
      ),
      'SPV',
    );

    final user = AppUser.fromMap({
      'id': 'krisna',
      'email': krisnaQaSpvEmail,
      'name': 'Krisna Bagus Andrian',
      'role': 'MANAGER',
      'action': 'all',
    });
    expect(user.role, 'SPV');
  });

  test('other accounts retain their configured role', () {
    expect(
      effectiveAppUserRole(email: 'manager@example.test', role: 'MANAGER'),
      'MANAGER',
    );
  });

  test('legacy local Manager session is read back as QA SPV', () async {
    SharedPreferences.setMockInitialValues({
      SessionKeys.activeUserId: 'krisna',
      SessionKeys.activeUserEmail: krisnaQaSpvEmail,
      SessionKeys.activeUserName: 'Krisna Bagus Andrian',
      SessionKeys.activeUserRole: 'MANAGER',
      SessionKeys.activeUserAction: 'all',
    });

    final session = await SessionManager.instance.getActiveSession();
    expect(session?.role, 'SPV');
  });
}
