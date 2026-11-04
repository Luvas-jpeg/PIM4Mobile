import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api_client.dart';
import 'core/course_reminders.dart';
import 'features/detail_pages.dart';
import 'features/login_page.dart';
import 'features/student_home.dart';

class StudentApp extends StatefulWidget {
  const StudentApp({required this.api, this.notifications, super.key});
  final CourseReminders? notifications;
  final ApiClient api;
  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  late Future<void> _restore;
  final _navigator = GlobalKey<NavigatorState>();
  int? _openingId;
  @override
  void initState() {
    super.initState();
    _restore = widget.api.restore();
    widget.api.addListener(_sessionChanged);
    widget.notifications?.onOpen = _openEnrollment;
  }

  void _openEnrollment(int id) {
    if (!mounted || !widget.api.signedIn || _openingId == id) return;
    _openingId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.api.signedIn) return;
      final navigator = _navigator.currentState;
      if (navigator == null) return;
      widget.notifications?.pendingEnrollmentId = null;
      _openingId = null;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => EnrollmentPage(api: widget.api, id: id),
        ),
      );
    });
  }

  void _sessionChanged() {
    final pending = widget.notifications?.pendingEnrollmentId;
    if (widget.api.signedIn && pending != null) _openEnrollment(pending);
    if (!widget.api.signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigator.currentState?.popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.api.removeListener(_sessionChanged);
    widget.notifications?.onOpen = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    title: 'MediShop Aluno',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315cfd)),
      scaffoldBackgroundColor: const Color(0xfff7f9fb),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xfff7f9fb)),
    ),
    home: FutureBuilder<void>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Não foi possível abrir sua sessão. Tente novamente.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        _restore = widget.api.restore();
                      }),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return AnimatedBuilder(
          animation: widget.api,
          builder: (context, _) => widget.api.signedIn
              ? StudentHome(
                  api: widget.api,
                  notifications: widget.notifications,
                )
              : LoginPage(api: widget.api),
        );
      },
    ),
  );
}
