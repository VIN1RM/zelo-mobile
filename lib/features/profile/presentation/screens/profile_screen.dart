import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/account_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final name = TextEditingController();
  final password = TextEditingController();
  bool initialized = false;
  @override
  void dispose() {
    name.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final user = ref.watch(authUserProvider).asData?.value;
      if (!initialized) {
        name.text = user?.name ?? '';
        initialized = true;
      }
      final service = AccountService(
        app.repository,
        FirebaseAuth.instance,
        FirebaseFirestore.instance,
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Minha conta')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(user?.email ?? ''),
            const Text('E-mail verificado'),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              maxLength: 80,
              enabled: !data.busy,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            FilledButton(
              onPressed: data.busy
                  ? null
                  : () => uiAction(
                      context,
                      () => app.operation(() => service.rename(name.text)),
                      success: 'Nome atualizado.',
                    ),
              child: const Text('Salvar nome'),
            ),
            TextButton(
              onPressed: data.busy
                  ? null
                  : () async {
                      if (await confirmAction(
                            context,
                            'Sair da conta?',
                            'Você precisará entrar novamente. Dados locais continuam isolados por usuário.',
                          ) &&
                          context.mounted) {
                        await uiAction(
                          context,
                          () => app.operation(
                            service.signOut,
                            allowDuringDeletion: true,
                          ),
                        );
                      }
                    },
              child: const Text('Sair da conta'),
            ),
            const Divider(),
            const Text(
              'Excluir conta e dados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Exige internet, autenticação recente e proteção encerrada. Falhas deixam a operação pendente para nova tentativa. Um marcador técnico mínimo, sem nome, e-mail, contatos ou localização, permanece para impedir que aparelhos antigos recriem os dados. A senha é usada somente para reautenticação.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              enabled: !data.busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Senha para confirmar exclusão',
              ),
            ),
            TextButton.icon(
              onPressed: data.busy
                  ? null
                  : () async {
                      if (password.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Informe sua senha.')),
                        );
                        return;
                      }
                      if (await confirmAction(
                            context,
                            'Excluir definitivamente?',
                            'Sua conta, registros remotos e arquivos locais serão removidos. Se houver falha, a operação ficará pendente para nova tentativa.',
                          ) &&
                          context.mounted) {
                        await uiAction(
                          context,
                          () => app.operation(
                            () => service.delete(password.text),
                            allowDuringDeletion: true,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Excluir conta e dados'),
            ),
            FutureBuilder(
              future: app.repository.preference('deleting'),
              builder: (context, snapshot) => snapshot.data == null
                  ? const SizedBox.shrink()
                  : const Text(
                      'Uma exclusão foi iniciada e ainda não foi concluída. Informe sua senha e tente novamente. Novas alterações e sincronização ficam bloqueadas até a conclusão.',
                    ),
            ),
          ],
        ),
      );
    },
  );
}
