import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pim4_aluno/core/api_client.dart';
import 'package:pim4_aluno/core/app_config.dart';

import 'widget_test.dart' show MemoryStore, session, jsonResponse;

void main() {
  test('login usa contrato real e persiste token sem senha', () async {
    final store = MemoryStore();
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: store,
      transport: MockClient((request) async {
        expect(request.url.path, '/api/Auth/login');
        expect(jsonDecode(request.body), {
          'email': 'aluno@example.com',
          'senha': 'SenhaDeTeste123',
        });
        return jsonResponse(session());
      }),
    );
    await api.login(' aluno@example.com ', 'SenhaDeTeste123');
    expect(api.signedIn, isTrue);
    expect(store.value, isNot(contains('SenhaDeTeste123')));
    expect(api.user['nome'], 'Aluno Teste');
    api.dispose();
  });

  test(
    '401 simultaneos compartilham uma renovacao e repetem com token novo',
    () async {
      final store = MemoryStore()..value = jsonEncode(session('old'));
      var refreshes = 0;
      final api = ApiClient(
        baseUrl: Uri.parse('http://localhost/'),
        store: store,
        transport: MockClient((request) async {
          if (request.url.path == '/api/Auth/refresh') {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return jsonResponse(session('new'));
          }
          if (request.headers['authorization'] == 'Bearer old') {
            return jsonResponse({}, 401);
          }
          expect(request.headers['authorization'], 'Bearer new');
          return jsonResponse([]);
        }),
      );
      await api.restore();
      await Future.wait([api.orders(), api.enrollments()]);
      expect(refreshes, 1);
      expect(jsonDecode(store.value!)['accessToken'], 'new');
      api.dispose();
    },
  );

  test('refresh recusado limpa sessao e pede novo login', () async {
    final store = MemoryStore()..value = jsonEncode(session());
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: store,
      transport: MockClient((request) async => jsonResponse({}, 401)),
    );
    await api.restore();
    await expectLater(api.orders(), throwsA(isA<ApiException>()));
    expect(api.signedIn, isFalse);
    expect(store.value, isNull);
    api.dispose();
  });

  test('renovacao que termina depois de logout nao restaura sessao', () async {
    final store = MemoryStore()..value = jsonEncode(session());
    final started = Completer<void>();
    final refresh = Completer<http.Response>();
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: store,
      transport: MockClient((request) async {
        if (request.url.path == '/api/Auth/refresh') {
          started.complete();
          return refresh.future;
        }
        if (request.url.path == '/api/Auth/logout') return jsonResponse({});
        return jsonResponse({}, 401);
      }),
    );
    await api.restore();
    final pending = expectLater(api.orders(), throwsA(isA<ApiException>()));
    await started.future;
    await api.logout();
    refresh.complete(jsonResponse(session('new')));
    await pending;
    expect(api.signedIn, isFalse);
    expect(store.value, isNull);
    api.dispose();
  });

  test('perfil salva os campos de endereco e atualiza sessao', () async {
    final store = MemoryStore()..value = jsonEncode(session());
    final fields = {
      ...session()['user'] as Map<String, dynamic>,
      'nome': 'Aluno Atualizado',
      'street': 'Rua Teste',
      'zipCode': '01001000',
    };
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: store,
      transport: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/Auth/perfil');
        expect(jsonDecode(request.body)['street'], 'Rua Teste');
        return jsonResponse(fields);
      }),
    );
    await api.restore();
    await api.updateProfile(fields);
    expect(api.user['nome'], 'Aluno Atualizado');
    expect(jsonDecode(store.value!)['user']['zipCode'], '01001000');
    api.dispose();
  });

  test('sessao armazenada corrompida e removida', () async {
    final store = MemoryStore()..value = '{invalido';
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: store,
    );
    await api.restore();
    expect(api.signedIn, isFalse);
    expect(store.value, isNull);
    api.dispose();
  });

  test('release exige HTTPS publico e URL sem /api duplicado', () {
    expect(
      () => AppConfig.validate('http://10.0.2.2:5278/', release: true),
      throwsFormatException,
    );
    expect(
      () => AppConfig.validate('https://servidor.example/api', release: true),
      throwsFormatException,
    );
    expect(
      AppConfig.validate('https://servidor.example', release: true).toString(),
      'https://servidor.example/',
    );
  });
}
