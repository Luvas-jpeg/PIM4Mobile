import 'dart:convert';

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pim4_aluno/core/api_client.dart';
import 'package:pim4_aluno/ui/enrollment_schedule.dart';

import 'widget_test.dart' show MemoryStore, session, jsonResponse;

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  final start = DateTime(2030, 6, 10, 15);
  Map<String, dynamic> item() => {
    'enrollmentId': 42,
    'courseId': 8,
    'deliveryMode': 'presencial',
    'startDate': start.toIso8601String(),
    'enrollmentStatus': 'active',
    'classStatus': 'scheduled',
  };
  test('contagem distingue hoje, amanha, datas futuras e turma iniciada', () {
    expect(
      courseStartMessage(item(), start.subtract(const Duration(days: 3))),
      contains('3 dias'),
    );
    expect(
      courseStartMessage(item(), start.subtract(const Duration(days: 1))),
      contains('amanhã'),
    );
    expect(
      courseStartMessage(item(), start.subtract(const Duration(hours: 1))),
      contains('É hoje'),
    );
    expect(courseStartMessage(item(), start), contains('já começou'));
    expect(
      courseStartMessage({...item(), 'classStatus': 'cancelled'}, start),
      contains('cancelada'),
    );
  });

  Future<ApiClient> apiFor(Future<dynamic> Function(dynamic) handler) async {
    final store = MemoryStore()..value = jsonEncode(session());
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: store,
      transport: MockClient((r) async => await handler(r)),
    );
    await api.restore();
    return api;
  }

  testWidgets(
    'confirma a matricula correta e apresenta o retorno persistido pela API',
    (tester) async {
      var calls = 0;
      final api = await apiFor((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/me/enrollments/42/participation');
        calls++;
        return jsonResponse({
          'status': 'confirmed',
          'confirmedAt': start
              .subtract(const Duration(days: 3))
              .toIso8601String(),
        });
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EnrollmentSchedule(
                api: api,
                item: item(),
                clock: () => start.subtract(const Duration(days: 3)),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Confirmar minha participação'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('✓ Participação confirmada'), findsOneWidget);
      expect(find.text('Confirmar minha participação'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  testWidgets('nao abre antes de sete dias e nao confirma turma cancelada', (
    tester,
  ) async {
    final api = await apiFor(
      (r) async => throw StateError('No API call expected'),
    );
    for (final entry in [
      (item(), start.subtract(const Duration(days: 8))),
      (
        {...item(), 'classStatus': 'cancelled'},
        start.subtract(const Duration(days: 2)),
      ),
      (item(), start),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnrollmentSchedule(
              key: UniqueKey(),
              api: api,
              item: entry.$1,
              clock: () => entry.$2,
            ),
          ),
        ),
      );
      expect(find.text('Confirmar minha participação'), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets('erro permite nova tentativa sem alterar o status da matricula', (
    tester,
  ) async {
    var calls = 0;
    final api = await apiFor((r) async {
      calls++;
      return calls == 1
          ? jsonResponse({'message': 'Tente novamente.'}, 503)
          : jsonResponse({
              'status': 'confirmed',
              'confirmedAt': start.toIso8601String(),
            });
    });
    final enrollment = item();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EnrollmentSchedule(
              api: api,
              item: enrollment,
              clock: () => start.subtract(const Duration(days: 3)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Confirmar minha participação'));
    await tester.pumpAndSettle();
    expect(find.text('Tente novamente.'), findsOneWidget);
    await tester.tap(find.text('Confirmar minha participação'));
    await tester.pumpAndSettle();
    expect(find.text('✓ Participação confirmada'), findsOneWidget);
    expect(enrollment['enrollmentStatus'], 'active');
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
