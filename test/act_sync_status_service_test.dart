import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kroscek/services/act_sync_status_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('ACT status RPC is not called before authentication is ready', () async {
    var requestCount = 0;
    final client = SupabaseClient(
      'https://act-status.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      ActSyncStatusService(client: client).getStatus(),
      throwsA(isA<ActSyncAuthenticationRequired>()),
    );
    expect(requestCount, 0);
  });
}
