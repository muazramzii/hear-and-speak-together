import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hear_speak_together/core/network/api_exception.dart';
import 'package:hear_speak_together/features/health/connection_screen.dart';
import 'package:hear_speak_together/models/health_status.dart';
import 'package:hear_speak_together/repositories/health_repository.dart';

/// A repository stub so tests never touch the network.
class _FakeHealthRepository implements HealthRepository {
  _FakeHealthRepository(this._result);

  final Future<HealthStatus> Function() _result;

  @override
  Future<HealthStatus> fetchHealth() => _result();
}

Widget _harness(HealthRepository repository) {
  return ProviderScope(
    overrides: [healthRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: ConnectionScreen()),
  );
}

void main() {
  group('ConnectionScreen', () {
    testWidgets('shows a loading state while the request is in flight', (
      tester,
    ) async {
      final completer = Completer<HealthStatus>();
      await tester.pumpWidget(
        _harness(_FakeHealthRepository(() => completer.future)),
      );
      await tester.pump();

      expect(find.text('Checking connection...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        const HealthStatus(
          status: 'ok',
          message: 'Hear & Speak Together API is running',
          database: 'connected',
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('shows Backend Connected when the API is healthy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          _FakeHealthRepository(
            () async => const HealthStatus(
              status: 'ok',
              message: 'Hear & Speak Together API is running',
              database: 'connected',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backend Connected'), findsOneWidget);
      expect(find.text('Backend Connection Failed'), findsNothing);
    });

    testWidgets('shows the failure state when the request throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          _FakeHealthRepository(
            () async =>
                throw const ApiException(
                  kind: ApiErrorKind.network,
                  message: 'Could not reach the server.',
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backend Connection Failed'), findsOneWidget);
      expect(find.text('Could not reach the server.'), findsOneWidget);
    });

    testWidgets('reports a degraded backend as a failure', (tester) async {
      await tester.pumpWidget(
        _harness(
          _FakeHealthRepository(
            () async => const HealthStatus(
              status: 'degraded',
              message: 'Hear & Speak Together API is running',
              database: 'unavailable',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backend Connection Failed'), findsOneWidget);
      expect(
        find.text('The API is running but cannot reach the database.'),
        findsOneWidget,
      );
    });
  });

  group('HealthStatus', () {
    test('parses a healthy payload', () {
      final status = HealthStatus.fromJson(const {
        'status': 'ok',
        'message': 'Hear & Speak Together API is running',
        'database': 'connected',
      });

      expect(status.isHealthy, isTrue);
      expect(status.isDatabaseConnected, isTrue);
    });

    test('falls back to unknown for missing fields', () {
      final status = HealthStatus.fromJson(const {});

      expect(status.status, 'unknown');
      expect(status.isHealthy, isFalse);
    });
  });
}
