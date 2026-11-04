import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/course_reminders.dart';
import '../ui/reminder_settings.dart';
import '../ui/shared.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({required this.api, this.notifications, super.key});
  final CourseReminders? notifications;
  final ApiClient api;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  bool _busy = false;
  String? _error;
  static const _labels = {
    'nome': 'Nome completo',
    'email': 'Email',
    'cpf': 'CPF',
    'phone': 'Telefone',
    'zipCode': 'CEP',
    'street': 'Rua',
    'number': 'Número',
    'complement': 'Complemento',
    'neighborhood': 'Bairro',
    'city': 'Cidade',
    'state': 'Estado (UF)',
  };
  @override
  void initState() {
    super.initState();
    for (final key in _labels.keys) {
      _fields[key] = TextEditingController(
        text: '${widget.api.user[key] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.updateProfile({
        for (final entry in _fields.entries)
          entry.key: entry.key == 'state'
              ? entry.value.text.trim().toUpperCase()
              : entry.value.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você poderá entrar novamente com a mesma conta do site.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar aqui'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.logout();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível limpar a sessão. Tente novamente.'),
          ),
        );
      }
    }
  }

  Widget _field(String key, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_busy,
      maxLength: switch (key) {
        'nome' => 120,
        'email' => 254,
        'cpf' => 14,
        'phone' => 20,
        'state' => 2,
        'zipCode' => 10,
        'number' => 20,
        'street' => 160,
        _ => 120,
      },
      keyboardType: key == 'email'
          ? TextInputType.emailAddress
          : ['cpf', 'phone', 'zipCode'].contains(key)
          ? TextInputType.phone
          : TextInputType.text,
      decoration: InputDecoration(labelText: _labels[key], counterText: ''),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Preencha este campo.';
        }
        if (key == 'email' &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                .hasMatch(value?.trim() ?? '')) {
          return 'Informe um email válido.';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const CircleAvatar(
        radius: 34,
        child: Icon(Icons.person_outline, size: 36),
      ),
      const SizedBox(height: 16),
      Text(
        'Seus dados',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 24),
      if (widget.notifications != null) ...[
        ReminderSettings(notifications: widget.notifications!),
        const SizedBox(height: 16),
      ],
      Form(
        key: _form,
        child: Column(
          children: [
            for (final key in ['nome', 'email', 'cpf', 'phone'])
              _field(key, required: true),
            ExpansionTile(
              title: const Text('Endereço'),
              tilePadding: EdgeInsets.zero,
              children: [
                for (final key in [
                  'zipCode',
                  'street',
                  'number',
                  'complement',
                  'neighborhood',
                  'city',
                  'state',
                ])
                  _field(key),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Aguarde...' : 'Salvar alterações'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => openSite(context, 'conta'),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Minha conta no site'),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _busy ? null : _logout,
        icon: const Icon(Icons.logout),
        label: const Text('Sair da conta'),
      ),
    ],
  );
}
