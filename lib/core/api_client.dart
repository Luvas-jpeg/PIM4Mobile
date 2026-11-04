import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session_store.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class ApiClient extends ChangeNotifier {
  ApiClient({
    required this.baseUrl,
    required this.store,
    http.Client? transport,
  }) : _http = transport ?? http.Client();

  final Uri baseUrl;
  final SessionStore store;
  final http.Client _http;
  Map<String, dynamic>? _session;
  int _epoch = 0;
  int _participationRevision = 0;
  bool _hasKnownSession = false;
  bool get hasKnownSession => _hasKnownSession;
  Future<void> Function()? onSessionEnding;
  void Function(List<Map<String, dynamic>>)? onEnrollmentsLoaded;
  void Function(Map<String, dynamic>)? onEnrollmentLoaded;
  void Function(int)? onParticipationConfirmed;
  Future<void>? _refreshing;
  Future<void> _storageQueue = Future<void>.value();

  bool get signedIn => _session != null;
  Map<String, dynamic> get user =>
      Map<String, dynamic>.from(_session?['user'] as Map? ?? {});
  String get _access => _session?['accessToken'] as String? ?? '';

  Future<void> _storageAction(Future<void> Function() action) {
    final operation = _storageQueue.then((_) => action());
    _storageQueue = operation.catchError((Object _) {});
    return operation;
  }

  Map<String, dynamic> _validSession(dynamic data) {
    if (data is! Map ||
        data['accessToken'] is! String ||
        (data['accessToken'] as String).isEmpty ||
        data['refreshToken'] is! String ||
        (data['refreshToken'] as String).isEmpty ||
        data['user'] is! Map) {
      throw const ApiException('A resposta de autenticação é inválida.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> restore() async {
    final epoch = _epoch;
    final value = await store.read();
    _hasKnownSession = true;
    if (value == null || epoch != _epoch) {
      notifyListeners();
      return;
    }
    try {
      _session = _validSession(jsonDecode(value));
      notifyListeners();
    } on FormatException {
      await _expire(epoch);
    } on ApiException {
      await _expire(epoch);
    }
  }

  Future<void> _save(Map<String, dynamic> data, int epoch) async {
    await _storageAction(() async {
      if (epoch == _epoch) await store.write(jsonEncode(data));
    });
    if (epoch != _epoch) {
      throw const ApiException('A sessão foi encerrada.', 401);
    }
    _session = data;
    _hasKnownSession = true;
    notifyListeners();
  }

  Future<void> _expire(int epoch) async {
    if (epoch != _epoch) return;
    _epoch++;
    _session = null;
    _hasKnownSession = true;
    notifyListeners();
    await _storageAction(store.clear);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? token,
  }) async {
    try {
      final request = http.Request(method, baseUrl.resolve(path));
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (data != null) request.body = jsonEncode(data);
      return await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException(
        'O servidor demorou para responder. Tente novamente.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Não foi possível conectar. Confira sua internet e tente novamente.',
      );
    }
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (response.statusCode < 400) {
        throw const ApiException('O servidor retornou uma resposta inválida.');
      }
    }
    if (response.statusCode >= 400) {
      final fallback = switch (response.statusCode) {
        401 => 'Sua sessão expirou. Entre novamente.',
        403 => 'Você não tem acesso a estas informações.',
        429 => 'Muitas tentativas. Aguarde um minuto e tente novamente.',
        _ => 'Não foi possível concluir. Tente novamente.',
      };
      final message = data is Map ? data['message'] : null;
      throw ApiException(
        message is String && message.isNotEmpty ? message : fallback,
        response.statusCode,
      );
    }
    return data;
  }

  Future<void> login(String email, String password) async {
    final epoch = ++_epoch;
    final response = await _send(
      'POST',
      'api/Auth/login',
      data: {'email': email.trim(), 'senha': password},
    );
    await _save(_validSession(_decode(response)), epoch);
  }

  Future<void> _refresh(int epoch) async {
    final refreshToken = _session?['refreshToken'] as String?;
    if (refreshToken == null || epoch != _epoch) {
      throw const ApiException('Entre novamente para continuar.', 401);
    }
    final response = await _send(
      'POST',
      'api/Auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _expire(epoch);
    }
    await _save(_validSession(_decode(response)), epoch);
  }

  Future<void> _refreshOnce(int epoch) async {
    if (_refreshing != null) return _refreshing!;
    final operation = _refresh(epoch);
    _refreshing = operation;
    try {
      await operation;
    } finally {
      if (identical(_refreshing, operation)) _refreshing = null;
    }
  }

  Future<dynamic> _authenticated(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (!signedIn) throw const ApiException('Entre para continuar.', 401);
    final epoch = _epoch;
    final sentToken = _access;
    var response = await _send(method, path, data: data, token: sentToken);
    if (epoch != _epoch) {
      throw const ApiException('A sessão foi encerrada.', 401);
    }
    if (response.statusCode == 401) {
      // Reutilizar o token renovado se outra chamada terminou primeiro.
      if (_access == sentToken) await _refreshOnce(epoch);
      if (epoch != _epoch) {
        throw const ApiException('A sessão foi encerrada.', 401);
      }
      response = await _send(method, path, data: data, token: _access);
      if (response.statusCode == 401) await _expire(epoch);
    }
    if (epoch != _epoch && response.statusCode != 401) {
      throw const ApiException('A sessão foi encerrada.', 401);
    }
    return _decode(response);
  }

  Future<Map<String, dynamic>> confirmParticipation(int id) async {
    final result = Map<String, dynamic>.from(
      await _authenticated(
        'POST',
        'api/me/enrollments/$id/participation',
        data: {},
      ) as Map,
    );
    _participationRevision++;
    if (result['status'] == 'confirmed') onParticipationConfirmed?.call(id);
    return result;
  }

  Future<List<Map<String, dynamic>>> enrollments() async {
    final revision = _participationRevision;
    final items = _list(await _authenticated('GET', 'api/me/courses'));
    if (revision == _participationRevision) onEnrollmentsLoaded?.call(items);
    return items;
  }

  Future<Map<String, dynamic>> enrollment(int id) async {
    final revision = _participationRevision;
    final item = Map<String, dynamic>.from(
      await _authenticated('GET', 'api/me/enrollments/$id') as Map,
    );
    if (revision == _participationRevision) onEnrollmentLoaded?.call(item);
    return item;
  }

  Future<List<Map<String, dynamic>>> orders() async =>
      _list(await _authenticated('GET', 'api/Orders/my'));
  Future<Map<String, dynamic>> order(int id) async => Map<String, dynamic>.from(
    await _authenticated('GET', 'api/Orders/$id') as Map,
  );
  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) {
      throw const ApiException('A lista recebida é inválida.');
    }
    return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    final epoch = _epoch;
    final result = await _authenticated('PUT', 'api/Auth/perfil', data: fields);
    if (epoch != _epoch) {
      throw const ApiException('A sessão foi encerrada.', 401);
    }
    await _save({
      ..._session!,
      'user': Map<String, dynamic>.from(result as Map),
    }, epoch);
  }

  Future<void> logout() async {
    final token = _access;
    final epoch = _epoch;
    // Limpar localmente mesmo se o servidor estiver indisponível.
    final remote = token.isEmpty
        ? Future<void>.value()
        : _send(
            'POST',
            'api/Auth/revoke',
            token: token,
            data: {'refreshToken': _session?['refreshToken']},
          ).then<void>((_) {}).catchError((Object _) {});
    await _expire(epoch);
    await onSessionEnding?.call();
    await remote;
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }
}
