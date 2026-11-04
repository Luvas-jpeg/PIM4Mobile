import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'reminder_device.dart';

abstract interface class ReminderStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureReminderStore implements ReminderStore {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class CourseReminders extends ChangeNotifier with WidgetsBindingObserver {
  CourseReminders(
    this.api, {
    ReminderDevice? device,
    ReminderStore? store,
    DateTime Function()? clock,
    this.supported,
  }) : _device = device ?? AndroidReminderDevice(),
       _store = store ?? SecureReminderStore(),
       _clock = clock ?? DateTime.now;
  final ApiClient api;
  final ReminderDevice _device;
  final ReminderStore _store;
  final DateTime Function() _clock;
  final bool? supported;
  bool available = false, enabled = false, busy = false;
  String? error, _owner, _installedOwner;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _queue = Future<void>.value();
  Map<String, dynamic> _ledger = {};
  final _latest = <int, Map<String, dynamic>>{};
  Map<String, dynamic>? _pending;
  void Function(int)? onOpen;
  int? get pendingEnrollmentId =>
      api.signedIn && _pending?['owner'] == '${api.user['id']}'
      ? (_pending?['enrollmentId'] as int?)
      : null;
  set pendingEnrollmentId(int? value) {
    if (value == null) _pending = null;
  }

  String get _preferenceKey => 'course_reminders_enabled_$_owner';
  String get _ledgerKey => 'course_reminders_ledger_$_owner';

  Future<void> initialize() async {
    final supported =
        this.supported ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    if (!supported) return;
    try {
      await _device.initialize(_onTap);
      _installedOwner = await _store.read('course_reminders_owner');
      available = true;
      WidgetsBinding.instance.addObserver(this);
      api.onEnrollmentsLoaded = (items) =>
          _enqueue(() => _sync(items, complete: true));
      api.onEnrollmentLoaded = (item) =>
          _enqueue(() => _sync([item], complete: false));
      api.onParticipationConfirmed = (id) => _enqueue(() async {
        _latest.remove(id);
        _ledger.remove('$id');
        await _device.cancel(id);
        await _saveLedger();
      });
      api.onSessionEnding = () => _queue;
      api.addListener(_sessionChanged);
      _sessionChanged();
    } catch (_) {
      available = false;
    }
  }

  Future<void> get settled async {
    Future<void> current;
    do {
      current = _queue;
      await current;
    } while (!identical(current, _queue));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() work) {
    final generation = _generation;
    _queue = _queue
        .catchError((Object _) {})
        .then((_) async {
          if (_disposed || generation != _generation) return;
          await work();
        })
        .catchError((Object _) {
          error = 'Não foi possível atualizar os lembretes. Tente sincronizar novamente.';
          _notify();
        });
    return _queue;
  }

  void _sessionChanged() {
    if (!api.hasKnownSession) return;
    final owner = api.signedIn ? '${api.user['id']}' : '';
    if (_owner == owner) return;
    _owner = owner;
    final generation = ++_generation;
    enabled = false;
    _latest.clear();
    _ledger = {};
    unawaited(
      _enqueue(() async {
        if (_installedOwner != owner || owner.isEmpty) {
          await _device.cancelAll();
        }
        if (generation != _generation) return;
        _installedOwner = owner;
        await _store.write('course_reminders_owner', owner);
        if (generation != _generation) return;
        if (owner.isEmpty) {
          _notify();
          return;
        }
        final optedIn =
            await _store.read('course_reminders_enabled_$owner') == 'true';
        if (generation != _generation) return;
        final saved = await _store.read('course_reminders_ledger_$owner');
        if (generation != _generation) return;
        enabled = optedIn;
        if (saved != null) {
          try {
            _ledger = Map<String, dynamic>.from(jsonDecode(saved) as Map);
          } on FormatException {
            _ledger = {};
          } on TypeError {
            _ledger = {};
          }
        }
        _notify();
        if (enabled) await api.enrollments();
      }),
    );
    final pending = pendingEnrollmentId;
    if (pending != null) onOpen?.call(pending);
  }

  void _onTap(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is! Map ||
          data['owner'] is! String ||
          data['enrollmentId'] is! int ||
          (data['enrollmentId'] as int) <= 0) {
        return;
      }
      _pending = Map<String, dynamic>.from(data);
      final id = pendingEnrollmentId;
      if (id != null) onOpen?.call(id);
    } on FormatException {
      /* Ignore payloads unrelated to enrollment reminders. */
    }
  }

  Future<void> _saveLedger() async {
    if (_owner?.isNotEmpty == true) {
      await _store.write(_ledgerKey, jsonEncode(_ledger));
    }
  }

  Future<void> _sync(
    List<Map<String, dynamic>> items, {
    required bool complete,
  }) async {
    if (!available ||
        !enabled ||
        !api.signedIn ||
        _owner != '${api.user['id']}') {
      return;
    }
    if (complete) _latest.clear();
    for (final item in items) {
      final id = item['enrollmentId'];
      if (id is int) _latest[id] = item;
    }
    final generation = _generation;
    final now = _clock().toUtc();
    final plans = <int, CourseReminderPlan>{};
    for (final item in _latest.values) {
      final plan = CourseReminderPlan.fromEnrollment(item, _owner!, now);
      if (plan != null) plans[plan.id] = plan;
    }
    final pending = await _device.pendingIds();
    if (generation != _generation) return;
    for (final id in {...pending, ..._ledger.keys.map(int.parse)}) {
      if (id != 2147483646 &&
          !plans.containsKey(id) &&
          (complete || _latest.containsKey(id))) {
        await _device.cancel(id);
        if (generation != _generation) return;
        _ledger.remove('$id');
      }
    }
    if (!await _device.hasPermission()) {
      error = 'Permita notificações nas configurações do Android para receber os lembretes.';
      _notify();
      return;
    }
    if (generation != _generation) return;
    for (final plan in plans.values) {
      final previous = _ledger['${plan.id}'];
      if (previous is Map && previous['signature'] == plan.signature) {
        final oldWhen = DateTime.tryParse('${previous['when']}');
        if (pending.contains(plan.id) ||
            (oldWhen != null && !oldWhen.isAfter(now))) {
          continue;
        }
      }
      await _device.schedule(plan);
      if (generation != _generation) return;
      _ledger['${plan.id}'] = {
        'signature': plan.signature,
        'when': plan.when.toUtc().toIso8601String(),
      };
    }
    if (generation == _generation) await _saveLedger();
  }

  Future<void> activate() async {
    if (!available || busy || !api.signedIn) return;
    busy = true;
    error = null;
    _notify();
    try {
      if (!await _device.requestPermission()) {
        error = 'Permita notificações nas configurações do Android para receber os lembretes.';
        return;
      }
      enabled = true;
      await _store.write(_preferenceKey, 'true');
      await api.enrollments();
      await _queue;
    } catch (_) {
      error = 'Não foi possível carregar suas turmas. Confira a conexão e tente novamente.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> deactivate() async {
    if (!available || busy) return;
    enabled = false;
    _generation++;
    busy = true;
    error = null;
    _notify();
    try {
      await _enqueue(() async {
        await _device.cancelAll();
        _ledger.clear();
        await _store.write(_preferenceKey, 'false');
        await _saveLedger();
      });
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> preview() async {
    if (!available || busy || !enabled || !api.signedIn) return;
    busy = true;
    error = null;
    _notify();
    try {
      await api.enrollments();
      await _queue;
      final plans =
          _latest.values
              .map(
                (item) => CourseReminderPlan.fromEnrollment(
                  item,
                  _owner!,
                  _clock().toUtc(),
                ),
              )
              .whereType<CourseReminderPlan>()
              .toList()
            ..sort((a, b) => a.when.compareTo(b.when));
      if (plans.isEmpty) {
        error = 'Você precisa de uma turma futura ainda não confirmada para testar o lembrete.';
      } else {
        await _device.preview(plans.first);
      }
    } catch (_) {
      error = 'Não foi possível mostrar o lembrete de teste.';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        available &&
        enabled &&
        api.signedIn) {
      unawaited(
        api.enrollments().then<void>((_) {}).catchError((Object _) {
          error = 'Sem conexão para atualizar os lembretes. As datas salvas continuam agendadas.';
          _notify();
        }),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    api.removeListener(_sessionChanged);
    api.onEnrollmentsLoaded = null;
    api.onEnrollmentLoaded = null;
    api.onParticipationConfirmed = null;
    api.onSessionEnding = null;
    super.dispose();
  }
}
