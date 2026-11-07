import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/share_emergency.dart';

class AlertScreen extends StatelessWidget {
  const AlertScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final incident = data.incidents.where((i) => i.id == id).firstOrNull;
      final seconds =
          data.alertRemainingSeconds ??
          (incident?.deadline == null
              ? 0
              : max(
                  0,
                  (incident!.deadline!
                              .difference(DateTime.now().toUtc())
                              .inMilliseconds /
                          1000)
                      .ceil(),
                ));
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Possível acidente'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 72,
                  color: Colors.red,
                ),
                Text(
                  incident?.pending == true
                      ? 'Responda em $seconds segundos'
                      : outcomeLabel(
                          incident?.outcome ?? 'Registro indisponível',
                        ),
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Não confirmamos que houve um acidente. Escolha uma opção. Sem resposta, será preparada ajuda assistida, sem envio automático.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: incident?.pending == true && !data.emergencyBusy
                      ? () => uiAction(
                          context,
                          () => app.resolve(id, 'CANCELLED'),
                        )
                      : null,
                  child: const Text('Estou bem'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: incident?.pending == true && !data.emergencyBusy
                      ? () => uiAction(
                          context,
                          () => app.resolve(id, 'HELP_REQUESTED'),
                        )
                      : null,
                  child: const Text('Preciso de ajuda'),
                ),
                if (incident?.pending != true)
                  TextButton(
                    onPressed: () => context.go('/inicio'),
                    child: const Text('Voltar ao início'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String? contactId;
  bool sharing = false;
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final incident = data.incidents
          .where((i) => i.id == widget.id)
          .firstOrNull;
      final contact =
          data.contacts.where((c) => c.id == contactId).firstOrNull ??
          data.contacts.firstOrNull;
      if (incident == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Pedir ajuda')),
          body: const Center(
            child: Text('Registro não encontrado nesta conta.'),
          ),
        );
      }
      final name = ref.watch(authUserProvider).asData?.value?.name ?? '';
      Future<void> share(String channel) async {
        setState(() => sharing = true);
        try {
          await uiAction(
            context,
            () => ShareEmergency(
              app.repository,
            ).share(incident, name, channel, contact),
            success: 'Tentativa registrada. Envio e entrega não confirmados.',
          );
        } finally {
          if (mounted) setState(() => sharing = false);
        }
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Pedir ajuda'),
          leading: IconButton(
            tooltip: 'Voltar ao início',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/inicio'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              incident.label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(outcomeLabel(incident.outcome)),
            const SizedBox(height: 12),
            const Text(
              'Envio não confirmado. Você precisa concluir o envio no aplicativo escolhido. Se não houver canal disponível, copie a mensagem.',
            ),
            const SizedBox(height: 16),
            if (data.contacts.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: contact?.id,
                decoration: const InputDecoration(labelText: 'Contato'),
                items: data.contacts
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: sharing
                    ? null
                    : (value) => setState(() => contactId = value),
              ),
            const SizedBox(height: 16),
            SelectableText(
              ShareEmergency.message(incident, name, DateTime.now().toUtc()),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: sharing || contact?.phone == null
                  ? null
                  : () => share('whatsapp'),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Abrir WhatsApp'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: sharing || contact?.email == null
                  ? null
                  : () => share('email'),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Abrir e-mail'),
            ),
            TextButton.icon(
              onPressed: sharing ? null : () => share('copy'),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar mensagem'),
            ),
            TextButton(
              onPressed: () =>
                  context.push('/historico/incidents/${incident.id}'),
              child: const Text('Ver registro e atualizar minha condição'),
            ),
          ],
        ),
      );
    },
  );
}
