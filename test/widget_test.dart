import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pim4_aluno/core/api_client.dart';
import 'package:pim4_aluno/core/session_store.dart';
import 'package:pim4_aluno/student_app.dart';

class MemoryStore implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}

Map<String, dynamic> session([String token = 'token']) => {
  'accessToken': token,
  'refreshToken': 'refresh',
  'user': {
    'id': 1,
    'nome': 'Aluno Teste',
    'email': 'aluno@example.com',
    'cpf': '52998224725',
    'phone': '11999999999',
    'role': 'Cliente',
  },
};
const enrollment = {
  'enrollmentId': 42,
  'courseId': 8,
  'classId': 1,
  'orderId': 12,
  'courseName': 'Primeiros Socorros',
  'courseDescription': 'Curso de teste',
  'enrollmentStatus': 'active',
  'deliveryMode': 'presencial',
  'workloadHours': 8,
  'startDate': '2026-12-01T17:00:00Z',
  'endDate': null,
  'location': 'Unidade Centro',
  'instructor': 'Ana',
  'classStatus': 'scheduled',
};
http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets('login vazio mostra validacao sem chamar a API', (tester) async {
    var calls = 0;
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: MemoryStore(),
      transport: MockClient((request) async {
        calls++;
        return jsonResponse({});
      }),
    );
    await tester.pumpWidget(StudentApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um email válido.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets('matricula abre pelo ID da matricula e mostra turma correta', (
    tester,
  ) async {
    final store = MemoryStore()..value = jsonEncode(session());
    final paths = <String>[];
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: store,
      transport: MockClient((request) async {
        paths.add(request.url.path);
        return jsonResponse(switch (request.url.path) {
          '/api/me/courses' => [enrollment],
          '/api/me/enrollments/42' => enrollment,
          '/api/Orders/my' => [],
          _ => {},
        });
      }),
    );
    await tester.pumpWidget(StudentApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Primeiros Socorros'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver minha matrícula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver minha matrícula'));
    await tester.pumpAndSettle();
    expect(paths, contains('/api/me/enrollments/42'));
    expect(paths, isNot(contains('/api/me/enrollments/8')));
    expect(find.text('Unidade Centro'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Voltar para meus cursos'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar para meus cursos'));
    await tester.pumpAndSettle();
    expect(find.text('Meus cursos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets('erro na consulta oferece tentar novamente', (tester) async {
    final store = MemoryStore()..value = jsonEncode(session());
    var failed = true;
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: store,
      transport: MockClient(
        (request) async => request.url.path == '/api/me/courses' && failed
            ? jsonResponse({'message': 'Servidor indisponível.'}, 503)
            : jsonResponse([]),
      ),
    );
    await tester.pumpWidget(StudentApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Servidor indisponível.'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('Tentar novamente').first);
    await tester.pumpAndSettle();
    expect(find.text('Seu próximo passo começa aqui.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
