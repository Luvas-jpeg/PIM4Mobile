import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pim4_aluno/core/api_client.dart';

import 'widget_test.dart' show MemoryStore;

void main() {
  const enabled = bool.fromEnvironment('LIVE_API');
  test(
    'cliente Flutter autentica, consulta e salva perfil na API local real',
    () async {
      const address = String.fromEnvironment(
        'LIVE_API_URL',
        defaultValue: 'http://localhost:5278/',
      );
      final base = Uri.parse(address);
      if (!['localhost', '127.0.0.1'].contains(base.host)) {
        throw StateError('Use apenas a API local para criar dados fictícios.');
      }
      final run = DateTime.now().microsecondsSinceEpoch;
      final email = 'flutter-teste-$run@example.com';
      final password = 'AlunoTeste$run${Random.secure().nextInt(999999)}A';
      final transport = http.Client();
      final store = MemoryStore();
      final api = ApiClient(baseUrl: base, store: store);
      try {
        final registered = await transport.post(
          base.resolve('api/Auth/cadastrar'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nome': 'Aluno Flutter Teste',
            'email': email,
            'senha': password,
            'cpf': '52998224725',
            'phone': '11999999999',
          }),
        );
        expect(registered.statusCode, 200);
        await api.login(email, password);
        expect(api.user['email'], email);
        expect(await api.enrollments(), isEmpty);
        expect(await api.orders(), isEmpty);
        await api.updateProfile({
          ...api.user,
          'nome': 'Aluno Flutter Atualizado',
          'street': 'Rua de teste',
          'number': '10',
          'city': 'São Paulo',
          'state': 'SP',
          'zipCode': '01001000',
        });
        expect(api.user['nome'], 'Aluno Flutter Atualizado');
        await api.logout();
        expect(api.signedIn, isFalse);
        expect(store.value, isNull);
      } finally {
        api.dispose();
        transport.close();
      }
    },
    skip: !enabled,
  );
}
