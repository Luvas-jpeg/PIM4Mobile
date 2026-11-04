import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/course_reminders.dart';
import '../core/formatters.dart';
import '../ui/shared.dart';
import '../ui/enrollment_schedule.dart';
import 'detail_pages.dart';
import 'profile_page.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({required this.api, this.notifications, super.key});
  final CourseReminders? notifications;
  final ApiClient api;
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(['Meus cursos', 'Meus pedidos', 'Meu perfil'][_index]),
      actions: [
        IconButton(
          tooltip: 'Explorar cursos no site',
          onPressed: () => openSite(context),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: IndexedStack(
      index: _index,
      children: [
        CoursesPage(api: widget.api),
        OrdersPage(api: widget.api),
        ProfilePage(api: widget.api, notifications: widget.notifications),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school),
          label: 'Cursos',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Pedidos',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    ),
  );
}

class CoursesPage extends StatefulWidget {
  const CoursesPage({required this.api, super.key});
  final ApiClient api;
  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  String _search = '', _status = '';
  int _revision = 0;
  @override
  Widget build(BuildContext context) => AsyncPage<List<Map<String, dynamic>>>(
    key: ValueKey(_revision),
    load: widget.api.enrollments,
    builder: (context, all) {
      final visible = all
          .where(
            (item) =>
                (_status.isEmpty || item['enrollmentStatus'] == _status) &&
                ['courseName', 'location', 'instructor'].any(
                  (key) => textOf(
                    item,
                    key,
                  ).toLowerCase().contains(_search.toLowerCase()),
                ),
          )
          .toList();
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xff315cfd),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, ${textOf(widget.api.user, 'nome', 'aluno').split(' ').first}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Acompanhe suas matrículas e prepare-se para a próxima turma.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final entry in {
                'active': 'Ativas',
                'completed': 'Concluídas',
                'cancelled': 'Canceladas',
              }.entries)
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            '${all.where((e) => e['enrollmentStatus'] == entry.key).length}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            entry.value,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (all.isEmpty)
            const EmptyView(
              title: 'Seu próximo passo começa aqui.',
              message: 'Suas matrículas aparecem após a confirmação do pagamento no site.',
            )
          else ...[
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar curso, local ou instrutor',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Situação da matrícula',
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todas')),
                DropdownMenuItem(value: 'active', child: Text('Ativas')),
                DropdownMenuItem(value: 'completed', child: Text('Concluídas')),
                DropdownMenuItem(value: 'cancelled', child: Text('Canceladas')),
              ],
              onChanged: (value) => setState(() => _status = value ?? ''),
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhuma matrícula encontrada com esses filtros.'),
              ),
            for (final item in visible)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            color: Color(0xff315cfd),
                          ),
                          const Spacer(),
                          StatusBadge(textOf(item, 'enrollmentStatus')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        textOf(item, 'courseName'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      if (item['deliveryMode'] != 'ead') ...[
                        Text(dateOf(item['startDate'])),
                        const SizedBox(height: 6),
                        Text(textOf(item, 'location')),
                      ] else
                        const Text('Curso online'),
                      EnrollmentSchedule(
                        api: widget.api,
                        item: item,
                        key: ValueKey(item['enrollmentId']),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EnrollmentPage(
                                  api: widget.api,
                                  id: item['enrollmentId'] as int,
                                ),
                              ),
                            );
                            if (mounted) setState(() => _revision++);
                          },
                          child: const Text('Ver minha matrícula'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Puxe a tela para atualizar.',
              style: TextStyle(color: Color(0xff64748b)),
            ),
          ),
        ],
      );
    },
  );
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({required this.api, super.key});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => AsyncPage<List<Map<String, dynamic>>>(
    load: api.orders,
    builder: (context, orders) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (orders.isEmpty)
          const EmptyView(
            title: 'Você ainda não tem pedidos.',
            message: 'Escolha e compre seu curso pelo site. Acompanhe o pedido por aqui.',
          ),
        for (final item in orders)
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderPage(api: api, id: item['id'] as int),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pedido #${item['id']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        StatusBadge(textOf(item, 'paymentStatus')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(dateOf(item['dataPedido'])),
                    const SizedBox(height: 8),
                    Text(
                      moneyOf(item['total']),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Text('Ver detalhes'),
                        Spacer(),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
