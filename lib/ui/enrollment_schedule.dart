import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';

String courseStartMessage(Map<String, dynamic> item, DateTime now) {
  if (item['enrollmentStatus'] == 'cancelled' ||
      item['classStatus'] == 'cancelled') {
    return 'Turma ou matrícula cancelada';
  }
  if (item['enrollmentStatus'] == 'completed' ||
      ['completed', 'finished'].contains(item['classStatus'])) {
    return 'Turma encerrada';
  }
  final start = DateTime.tryParse('${item['startDate']}')?.toLocal();
  if (start == null || start.year < 1900) return 'Data a confirmar';
  if (!start.isAfter(now)) return 'Sua turma já começou';
  final days = DateTime.utc(
    start.year,
    start.month,
    start.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  if (days == 0) return 'É hoje! Prepare-se para sua turma.';
  if (days == 1) return 'Seu curso começa amanhã';
  return 'Seu curso começa em $days dias';
}

class EnrollmentSchedule extends StatefulWidget {
  const EnrollmentSchedule({
    required this.api,
    required this.item,
    this.clock,
    super.key,
  });
  final ApiClient api;
  final Map<String, dynamic> item;
  final DateTime Function()? clock;
  @override
  State<EnrollmentSchedule> createState() => _EnrollmentScheduleState();
}

class _EnrollmentScheduleState extends State<EnrollmentSchedule> {
  Timer? _timer;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _saved;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant EnrollmentSchedule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['enrollmentId'] != widget.item['enrollmentId'] ||
        oldWidget.item['startDate'] != widget.item['startDate']) {
      _saved = null;
      _error = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final id = widget.item['enrollmentId'] as int;
    final start = widget.item['startDate'];
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.api.confirmParticipation(id);
      if (mounted &&
          widget.item['enrollmentId'] == id &&
          widget.item['startDate'] == start) {
        setState(() => _saved = saved);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item['deliveryMode'] == 'ead') return const SizedBox.shrink();
    final now = (widget.clock ?? DateTime.now)().toLocal();
    final start = DateTime.tryParse('${item['startDate']}');
    final opens = start?.subtract(const Duration(days: 7));
    final eligible =
        item['enrollmentStatus'] == 'active' &&
        item['classStatus'] == 'scheduled';
    final participation = _saved ?? item['participation'] as Map?;
    final confirmed = eligible && participation?['status'] == 'confirmed';
    final canConfirm =
        eligible &&
        !confirmed &&
        start != null &&
        opens != null &&
        !now.isBefore(opens) &&
        now.isBefore(start);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffeef3ff),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffd8e2ff)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: Color(0xff315cfd),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  courseStartMessage(item, now),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (confirmed) ...[
            const SizedBox(height: 10),
            const Text(
              '✓ Participação confirmada',
              style: TextStyle(
                color: Color(0xff17603d),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text('Confirmada em ${dateOf(participation?['confirmedAt'])}'),
          ] else if (canConfirm) ...[
            const SizedBox(height: 10),
            const Text(
              'Confirme sua participação para ajudar na organização da turma.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _confirm,
                child: Text(
                  _busy ? 'Confirmando...' : 'Confirmar minha participação',
                ),
              ),
            ),
          ] else if (eligible && opens != null && now.isBefore(opens)) ...[
            const SizedBox(height: 10),
            Text(
              'A confirmação abre em ${dateOf(opens.toIso8601String())}, uma semana antes da turma.',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
