import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class CourseReminderPlan {
  const CourseReminderPlan({
    required this.id,
    required this.owner,
    required this.title,
    required this.body,
    required this.when,
    required this.signature,
  });
  final int id;
  final String owner, title, body, signature;
  final DateTime when;
  String get payload => jsonEncode({'enrollmentId': id, 'owner': owner});

  static CourseReminderPlan? fromEnrollment(
    Map<String, dynamic> item,
    String owner,
    DateTime now,
  ) {
    final id = item['enrollmentId'];
    final start = DateTime.tryParse('${item['startDate']}')?.toUtc();
    if (id is! int ||
        id <= 0 ||
        item['deliveryMode'] == 'ead' ||
        item['enrollmentStatus'] != 'active' ||
        item['classStatus'] != 'scheduled' ||
        start == null ||
        !start.isAfter(now.add(const Duration(seconds: 10))) ||
        (item['participation'] as Map?)?['status'] == 'confirmed') {
      return null;
    }
    final target = start.subtract(const Duration(days: 7));
    final when = target.isAfter(now)
        ? target
        : now.add(const Duration(seconds: 10));
    final days = target.isAfter(now)
        ? 7
        : (start.difference(now).inSeconds / 86400).ceil();
    final course = '${item['courseName'] ?? 'Seu curso'}';
    final local = start.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${two(local.day)}/${two(local.month)}';
    final time = '${two(local.hour)}:${two(local.minute)}';
    final place = '${item['location'] ?? 'Consulte sua matrícula'}';
    final title =
        '$course: ${days == 7
            ? 'começa em uma semana'
            : days > 1
            ? 'começa em $days dias'
            : 'está chegando'}!';
    final body =
        'Dia $date, às $time (${local.timeZoneName}). Local: $place. Toque para confirmar sua participação.';
    // Do not include the rolling "when" or days count: refreshing an imminent
    // enrollment must not generate another notification every time.
    final signature = jsonEncode([
      start.toIso8601String(),
      course,
      place,
      local.timeZoneOffset.inMinutes,
    ]);
    return CourseReminderPlan(
      id: id,
      owner: owner,
      title: title,
      body: body,
      when: when,
      signature: signature,
    );
  }
}

abstract interface class ReminderDevice {
  Future<void> initialize(void Function(String) onTap);
  Future<bool> requestPermission();
  Future<bool> hasPermission();
  Future<Set<int>> pendingIds();
  Future<void> schedule(CourseReminderPlan plan);
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<void> preview(CourseReminderPlan plan);
}

class AndroidReminderDevice implements ReminderDevice {
  final _plugin = FlutterLocalNotificationsPlugin();
  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  @override
  Future<void> initialize(void Function(String) onTap) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_school'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) onTap(response.payload!);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload != null) {
      onTap(launch!.notificationResponse!.payload!);
    }
  }

  NotificationDetails _details(CourseReminderPlan plan) => NotificationDetails(
    android: AndroidNotificationDetails(
      'course_start_reminders',
      'Início das turmas',
      channelDescription: 'Lembretes para confirmar a participação nas turmas',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      icon: 'ic_stat_school',
      styleInformation: BigTextStyleInformation(
        plan.body,
        contentTitle: plan.title,
      ),
    ),
  );
  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;
  @override
  Future<bool> hasPermission() async =>
      await _android?.areNotificationsEnabled() ?? false;
  @override
  Future<Set<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests()).map((n) => n.id).toSet();
  @override
  Future<void> schedule(CourseReminderPlan plan) => _plugin.zonedSchedule(
    id: plan.id,
    title: plan.title,
    body: plan.body,
    scheduledDate: tz.TZDateTime.from(plan.when, tz.UTC),
    notificationDetails: _details(plan),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: plan.payload,
  );
  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
  @override
  Future<void> cancelAll() => _plugin.cancelAll();
  @override
  Future<void> preview(CourseReminderPlan plan) => _plugin.show(
    id: 2147483646,
    title: 'Teste • ${plan.title}',
    body: plan.body,
    notificationDetails: _details(plan),
    payload: plan.payload,
  );
}
