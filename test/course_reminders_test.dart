import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pim4_aluno/core/api_client.dart';
import 'package:pim4_aluno/core/course_reminders.dart';
import 'package:pim4_aluno/core/reminder_device.dart';

import 'widget_test.dart' show MemoryStore, session, jsonResponse;

class MemoryReminderStore implements ReminderStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class FakeDevice implements ReminderDevice {
  final pending = <int, CourseReminderPlan>{};
  final schedules = <CourseReminderPlan>[];
  final previews = <CourseReminderPlan>[];
  bool permission = true;
  int cancelAllCalls = 0;
  void Function(String)? onTap;
  @override
  Future<void> initialize(void Function(String) onTap) async {
    this.onTap = onTap;
  }

  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();
  @override
  Future<void> schedule(CourseReminderPlan plan) async {
    schedules.add(plan);
    pending[plan.id] = plan;
  }

  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    pending.clear();
  }

  @override
  Future<void> preview(CourseReminderPlan plan) async {
    previews.add(plan);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2030, 6, 1, 12);
  Map<String, dynamic> enrollment([int days = 10]) => {
    'enrollmentId': 42,
    'courseId': 8,
    'courseName': 'Primeiros Socorros',
    'startDate': now.add(Duration(days: days)).toIso8601String(),
    'location': 'Unidade Centro',
    'enrollmentStatus': 'active',
    'classStatus': 'scheduled',
    'deliveryMode': 'presencial',
    'participation': {'status': 'waiting'},
  };

  test('agenda sete dias antes com texto especifico e ignora cancelados, EAD e confirmados', () {
    final plan = CourseReminderPlan.fromEnrollment(enrollment(), '1', now)!;
    expect(plan.when, now.add(const Duration(days: 3)));
    expect(plan.title, contains('Primeiros Socorros'));
    expect(plan.body, contains('Unidade Centro'));
    expect(jsonDecode(plan.payload)['enrollmentId'], 42);
    expect(
      CourseReminderPlan.fromEnrollment(
        {...enrollment(), 'classStatus': 'cancelled'},
        '1',
        now,
      ),
      isNull,
    );
    expect(
      CourseReminderPlan.fromEnrollment(
        {...enrollment(), 'deliveryMode': 'ead'},
        '1',
        now,
      ),
      isNull,
    );
    expect(
      CourseReminderPlan.fromEnrollment(
        {
          ...enrollment(),
          'participation': {'status': 'confirmed'},
        },
        '1',
        now,
      ),
      isNull,
    );
    expect(CourseReminderPlan.fromEnrollment(enrollment(0), '1', now), isNull);
    final imminent = CourseReminderPlan.fromEnrollment(
      enrollment(3),
      '1',
      now,
    )!;
    expect(imminent.when, now.add(const Duration(seconds: 10)));
    expect(imminent.title, contains('3 dias'));
  });

  test('sincroniza sem duplicar, atualiza data, testa sem substituir e cancela ao confirmar', () async {
    final device = FakeDevice(), store = MemoryReminderStore();
    var items = <Map<String, dynamic>>[enrollment()];
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost/'),
      store: MemoryStore()..value = jsonEncode(session()),
      transport: MockClient((r) async {
        if (r.method == 'POST') return jsonResponse({'status': 'confirmed'});
        return jsonResponse(items);
      }),
    );
    await api.restore();
    final service = CourseReminders(
      api,
      device: device,
      store: store,
      clock: () => now,
      supported: true,
    );
    await service.initialize();
    await service.settled;
    await service.activate();
    await service.settled;
    expect(device.schedules.length, 1);
    await api.enrollments();
    await service.settled;
    expect(device.schedules.length, 1);
    items = [enrollment(12)];
    await api.enrollments();
    await service.settled;
    expect(device.schedules.length, 2);
    expect(device.pending[42]!.when, now.add(const Duration(days: 5)));
    await service.preview();
    expect(device.previews.length, 1);
    expect(device.pending[42]!.when, now.add(const Duration(days: 5)));
    await api.confirmParticipation(42);
    await service.settled;
    expect(device.pending, isEmpty);
    await api.logout();
    expect(device.pending, isEmpty);
    service.dispose();
    api.dispose();
  });

  test(
    'nao repete lembrete ja disparado e cancela matricula ausente da lista',
    () async {
      final device = FakeDevice(), store = MemoryReminderStore();
      var items = <Map<String, dynamic>>[enrollment(3)];
      final api = ApiClient(
        baseUrl: Uri.parse('http://localhost/'),
        store: MemoryStore()..value = jsonEncode(session()),
        transport: MockClient((r) async => jsonResponse(items)),
      );
      await api.restore();
      var clock = now;
      final service = CourseReminders(
        api,
        device: device,
        store: store,
        clock: () => clock,
        supported: true,
      );
      await service.initialize();
      await service.settled;
      await service.activate();
      device.pending.clear();
      clock = now.add(const Duration(minutes: 1));
      await api.enrollments();
      await service.settled;
      expect(device.schedules.length, 1);
      items = [];
      await api.enrollments();
      await service.settled;
      expect(device.pending, isEmpty);
      service.dispose();
      api.dispose();
    },
  );

  test(
    'permissao recusada nao agenda e toque de outra conta nao abre matricula',
    () async {
      final device = FakeDevice()..permission = false;
      final api = ApiClient(
        baseUrl: Uri.parse('http://localhost/'),
        store: MemoryStore()..value = jsonEncode(session()),
        transport: MockClient((r) async => jsonResponse([enrollment()])),
      );
      await api.restore();
      final service = CourseReminders(
        api,
        device: device,
        store: MemoryReminderStore(),
        clock: () => now,
        supported: true,
      );
      await service.initialize();
      await service.settled;
      await service.activate();
      expect(service.enabled, isFalse);
      expect(device.pending, isEmpty);
      var opened = 0;
      service.onOpen = (_) => opened++;
      device.onTap!(jsonEncode({'owner': '999', 'enrollmentId': 42}));
      expect(opened, 0);
      expect(service.pendingEnrollmentId, isNull);
      device.onTap!(jsonEncode({'owner': '1', 'enrollmentId': 42}));
      expect(opened, 1);
      expect(service.pendingEnrollmentId, 42);
      service.dispose();
      api.dispose();
    },
  );

  test(
    'sessao expirada durante sincronizacao termina sem travar nem agendar',
    () async {
      final device = FakeDevice();
      final store = MemoryReminderStore()
        ..values['course_reminders_enabled_1'] = 'true';
      final api = ApiClient(
        baseUrl: Uri.parse('http://localhost/'),
        store: MemoryStore()..value = jsonEncode(session()),
        transport: MockClient(
          (r) async => jsonResponse({'message': 'Expirado'}, 401),
        ),
      );
      await api.restore();
      final service = CourseReminders(
        api,
        device: device,
        store: store,
        clock: () => now,
        supported: true,
      );
      await service.initialize();
      await service.settled.timeout(const Duration(seconds: 2));
      expect(api.signedIn, isFalse);
      expect(device.pending, isEmpty);
      service.dispose();
      api.dispose();
    },
  );
  test(
    'consultar uma matricula nao remove lembretes dos outros cursos',
    () async {
      final device = FakeDevice();
      final items = [
        enrollment(),
        {...enrollment(11), 'enrollmentId': 43},
      ];
      final api = ApiClient(
        baseUrl: Uri.parse('http://localhost/'),
        store: MemoryStore()..value = jsonEncode(session()),
        transport: MockClient((request) async => jsonResponse(items)),
      );
      await api.restore();
      final service = CourseReminders(
        api,
        device: device,
        store: MemoryReminderStore(),
        clock: () => now,
        supported: true,
      );
      await service.initialize();
      await service.settled;
      await service.activate();
      expect(device.pending.keys.toSet(), {42, 43});
      api.onEnrollmentLoaded?.call({
        ...enrollment(),
        'enrollmentStatus': 'cancelled',
      });
      await service.settled;
      expect(device.pending.keys.toSet(), {43});
      service.dispose();
      api.dispose();
    },
  );
}
