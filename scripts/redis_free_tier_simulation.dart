import 'dart:io';

const redisByteGuard = 8_000_000_000;
const redisOpsGuard = 350_000;
const mapPayloadCap = 1_000_000;
const coveragePayloadCap = 1_500_000;

void main(List<String> arguments) {
  final users = _argument(arguments, '--users', 100);
  final sessionsPerDay = _argument(arguments, '--sessions-per-day', 5);
  final days = _argument(arguments, '--days', 30);
  final datasetsPerSession = 2;

  final requests = users * sessionsPerDay * days * datasetsPerSession;
  final worstCaseBytes =
      users * sessionsPerDay * days * (mapPayloadCap + coveragePayloadCap);
  final guardedBytes = worstCaseBytes > redisByteGuard
      ? redisByteGuard
      : worstCaseBytes;
  final guardedOps = requests > redisOpsGuard ? redisOpsGuard : requests;

  stdout.writeln('Kroscek Redis free-tier simulation');
  stdout.writeln('users=$users sessions/day=$sessionsPerDay days=$days');
  stdout.writeln('full payload requests=$requests');
  stdout.writeln('worst-case bandwidth=${_gigabytes(worstCaseBytes)} GB/month');
  stdout.writeln(
    'application guard=${_gigabytes(guardedBytes)} / '
    '${_gigabytes(redisByteGuard)} GB',
  );
  stdout.writeln('logical operations=$guardedOps / $redisOpsGuard');
  stdout.writeln(
    worstCaseBytes > redisByteGuard
        ? 'result=SAFE_FAIL_OPEN (Redis stops; Supabase remains available)'
        : 'result=SAFE_WITHIN_GUARD',
  );
}

int _argument(List<String> arguments, String name, int fallback) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return fallback;
  return int.tryParse(arguments[index + 1]) ?? fallback;
}

String _gigabytes(int bytes) => (bytes / 1_000_000_000).toStringAsFixed(2);
