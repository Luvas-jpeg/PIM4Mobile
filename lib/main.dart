import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_config.dart';
import 'core/session_store.dart';
import 'core/course_reminders.dart';
import 'student_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AppConfig.site;
    final api = ApiClient(baseUrl: AppConfig.api, store: SecureSessionStore());
    final notifications = CourseReminders(api);
    await notifications.initialize();
    runApp(StudentApp(api: api, notifications: notifications));
  } on FormatException catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.message.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
