import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../ui/shared.dart';
import '../ui/enrollment_schedule.dart';

class EnrollmentPage extends StatelessWidget {
  const EnrollmentPage({required this.api, required this.id, super.key});
  final ApiClient api;
  final int id;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Minha matrícula')),
    body: AsyncPage<Map<String, dynamic>>(
      load: () => api.enrollment(id),
      builder: (context, item) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          StatusBadge(textOf(item, 'enrollmentStatus')),
          const SizedBox(height: 20),
          Text(
            textOf(item, 'courseName'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(textOf(item, 'courseDescription')),
          EnrollmentSchedule(api: api, item: item),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informações do curso',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  InfoRow(
                    'Carga horária',
                    '${item['workloadHours'] ?? 0} horas',
                  ),
                  if (item['deliveryMode'] != 'ead') ...[
                    InfoRow('Início', dateOf(item['startDate'])),
                    if (item['endDate'] != null)
                      InfoRow('Término', dateOf(item['endDate'])),
                    InfoRow('Local', textOf(item, 'location')),
                    InfoRow('Instrutor', textOf(item, 'instructor')),
                    InfoRow(
                      'Situação da turma',
                      statusOf(textOf(item, 'classStatus')),
                    ),
                  ] else
                    const InfoRow(
                      'Modalidade',
                      'Online — conteúdo disponível na área do aluno do site',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Confira data, local e orientações do instituto antes do início da aula.',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderPage(api: api, id: item['orderId'] as int),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Ver pedido'),
          ),
          if (item['deliveryMode'] == 'ead')
            OutlinedButton.icon(
              onPressed: () => openSite(context, 'area-aluno/matricula/$id'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir curso no site'),
            ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar para meus cursos'),
          ),
        ],
      ),
    ),
  );
}

class OrderPage extends StatelessWidget {
  const OrderPage({required this.api, required this.id, super.key});
  final ApiClient api;
  final int id;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Pedido #$id')),
    body: AsyncPage<Map<String, dynamic>>(
      load: () => api.order(id),
      builder: (context, order) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          StatusBadge(textOf(order, 'paymentStatus')),
          const SizedBox(height: 20),
          Text(
            moneyOf(order['total']),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          InfoRow('Data do pedido', dateOf(order['dataPedido'])),
          InfoRow('Forma de pagamento', switch (order['paymentMethod']) {
            'pix' => 'Pix',
            'credit_card' => 'Cartão de crédito',
            'debit_card' => 'Cartão de débito',
            _ => textOf(order, 'paymentMethod'),
          }),
          InfoRow('Situação do pedido', statusOf(textOf(order, 'status'))),
          if (order['paidAt'] != null)
            InfoRow('Pagamento confirmado em', dateOf(order['paidAt'])),
          const SizedBox(height: 16),
          for (final value in order['itens'] as List? ?? [])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${value['nome']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('${value['quantidade']} inscrição(ões)'),
                    Text('Valor unitário: ${moneyOf(value['precoUnitario'])}'),
                    if (value['turmaId'] != null)
                      Text('Turma #${value['turmaId']}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => openSite(context, 'conta/pedido/$id'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir pedido no site'),
          ),
        ],
      ),
    ),
  );
}
