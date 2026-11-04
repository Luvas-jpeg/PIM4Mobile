import 'package:intl/intl.dart';

String textOf(Map<String, dynamic> data, String key, [String fallback = '']) =>
    data[key]?.toString() ?? fallback;

String dateOf(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null || date.year < 1900) return 'Data a confirmar';
  return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(date.toLocal());
}

String moneyOf(dynamic value) => NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
).format(value is num ? value : num.tryParse('$value') ?? 0);

String statusOf(String status) => switch (status) {
  'active' => 'Ativa',
  'completed' => 'Concluída',
  'cancelled' => 'Cancelada',
  'scheduled' => 'Agendada',
  'pending' => 'Pendente',
  'paid' => 'Pago',
  'refused' => 'Recusado',
  'refunded' => 'Reembolsado',
  'expired' => 'Expirado',
  _ => status.isEmpty ? 'Não informado' : status,
};
