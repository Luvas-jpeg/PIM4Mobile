import 'package:flutter/material.dart';

import '../core/course_reminders.dart';

class ReminderSettings extends StatelessWidget {
  const ReminderSettings({required this.notifications, super.key});
  final CourseReminders notifications;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: notifications,
    builder: (context, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lembretes da sua turma',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              notifications.available
                  ? 'Agende no celular um aviso uma semana antes da turma. Abra o app para manter datas e cancelamentos atualizados.'
                  : 'Acompanhe a data por aqui. Os lembretes são agendados no aplicativo Android.',
            ),
            if (notifications.available) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: notifications.busy
                    ? null
                    : notifications.enabled
                    ? notifications.deactivate
                    : notifications.activate,
                icon: Icon(
                  notifications.enabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_outlined,
                ),
                label: Text(
                  notifications.busy
                      ? 'Aguarde...'
                      : notifications.enabled
                      ? 'Desativar lembretes'
                      : 'Ativar lembretes',
                ),
              ),
            ],
            if (notifications.available && notifications.enabled)
              TextButton(
                onPressed: notifications.busy ? null : notifications.preview,
                child: const Text('Testar notificação'),
              ),
            if (notifications.error != null)
              Text(
                notifications.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
  );
}
