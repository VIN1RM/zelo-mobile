import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_view.dart';

enum _DemoStage { introduction, alert, safe, help, timedOut }

class DemoScreen extends StatefulWidget {
  const DemoScreen({this.now = DateTime.now, super.key});

  final DateTime Function() now;

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _scroll = ScrollController();
  Timer? _timer;
  DateTime? _deadline;
  _DemoStage _stage = _DemoStage.introduction;

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _show(_DemoStage stage) {
    _timer?.cancel();
    setState(() {
      _stage = stage;
      _deadline = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _start() {
    _show(_DemoStage.alert);
    _deadline = widget.now().add(const Duration(seconds: 30));
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (!_deadline!.isAfter(widget.now())) {
        _show(_DemoStage.timedOut);
      } else {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final blocked =
          data.running || data.session != null || data.alert != null;
      if (blocked) {
        _timer?.cancel();
        _deadline = null;
        _stage = _DemoStage.introduction;
        return Scaffold(
          appBar: const AppHeader(title: Text('Demonstração')),
          body: AppScrollView(
            children: [
              AppEmptyState(
                icon: data.alert != null
                    ? Icons.warning_amber_rounded
                    : Icons.shield_outlined,
                title: data.alert != null
                    ? 'Existe um alerta real pendente'
                    : 'Sua proteção está em andamento',
                message: data.alert != null
                    ? 'Responda ao alerta real antes de experimentar a simulação.'
                    : 'Encerre a proteção no início para experimentar com tranquilidade.',
                action: FilledButton(
                  onPressed: () => context.go(
                    data.alert != null
                        ? '/alerta/${data.alert!.id}'
                        : '/inicio',
                  ),
                  child: Text(
                    data.alert != null ? 'Ver alerta real' : 'Voltar ao início',
                  ),
                ),
              ),
            ],
          ),
        );
      }
      final scheme = Theme.of(context).colorScheme;
      final introduction = _stage == _DemoStage.introduction;
      final alert = _stage == _DemoStage.alert;
      final safe = _stage == _DemoStage.safe;
      final result = !introduction && !alert;
      final step = introduction
          ? 1
          : alert
          ? 2
          : 3;
      final remaining = _deadline == null
          ? 0
          : (_deadline!.difference(widget.now()).inMilliseconds / 1000)
                .ceil()
                .clamp(0, 30);
      return Scaffold(
        appBar: const AppHeader(title: Text('Demonstração')),
        body: AppContent(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const SectionHeading(
                'Experimente antes de precisar',
                subtitle:
                    'Conheça o alerta e descubra o que acontece em cada resposta.',
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'SIMULAÇÃO · Nenhuma mensagem será enviada',
                        style: TextStyle(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                label: 'Etapa $step de 3',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in [
                      (1, 'Cenário'),
                      (2, 'Alerta'),
                      (3, 'Resultado'),
                    ])
                      Chip(
                        avatar: Icon(
                          item.$1 < step
                              ? Icons.check_rounded
                              : item.$1 == step
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                        ),
                        label: Text('${item.$1}. ${item.$2}'),
                        backgroundColor: item.$1 == step
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerLow,
                        labelStyle: TextStyle(
                          color: item.$1 == step
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Icon(
                          introduction
                              ? Icons.two_wheeler_rounded
                              : alert
                              ? Icons.warning_amber_rounded
                              : safe
                              ? Icons.check_circle_outline_rounded
                              : Icons.mark_chat_unread_outlined,
                          size: 48,
                          color: alert ? scheme.error : scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        introduction
                            ? 'Imagine este cenário'
                            : alert
                            ? 'Você está bem?'
                            : safe
                            ? 'Alerta simulado cancelado'
                            : _stage == _DemoStage.timedOut
                            ? 'O tempo terminou'
                            : 'Ajuda simulada preparada',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        introduction
                            ? 'Durante um trajeto fictício, o ZELO identifica um movimento que pode indicar um acidente. Um alerta pede que você confirme como está.'
                            : alert
                            ? 'Um possível acidente foi simulado. Responda antes de a contagem terminar.'
                            : safe
                            ? 'Você confirmou que está bem. No fluxo real, essa resposta cancela o alerta e o resultado fica registrado no histórico.'
                            : _stage == _DemoStage.timedOut
                            ? 'Sem resposta em 30 segundos, o fluxo real disponibiliza o pedido de ajuda. O envio de uma mensagem ainda depende da sua ação.'
                            : 'No fluxo real, você escolhe o contato e o canal, confere a mensagem e confirma o envio no aplicativo escolhido.',
                        textAlign: TextAlign.center,
                      ),
                      if (introduction) ...[
                        const SizedBox(height: 20),
                        const _DemoExplanation(
                          icon: Icons.timer_outlined,
                          title: '30 segundos para responder',
                          message:
                              'Cancele o alerta se estiver bem ou escolha pedir ajuda.',
                        ),
                        const _DemoExplanation(
                          icon: Icons.touch_app_outlined,
                          title: 'O envio depende de você',
                          message:
                              'O ZELO prepara a ajuda; a mensagem não é enviada automaticamente.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Iniciar simulação'),
                        ),
                      ],
                      if (alert) ...[
                        const SizedBox(height: 24),
                        AlertCountdown(seconds: remaining),
                        const SizedBox(height: 24),
                        ResponsiveActions(
                          children: [
                            FilledButton.icon(
                              onPressed: () => _show(_DemoStage.safe),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Estou bem'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _show(_DemoStage.help),
                              icon: const Icon(Icons.sos_rounded),
                              label: const Text('Preciso de ajuda'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _show(_DemoStage.introduction),
                          child: const Text('Sair da simulação'),
                        ),
                      ],
                      if (result) ...[
                        if (!safe) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'PRÉVIA FICTÍCIA',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Para: Contato de exemplo',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'SIMULAÇÃO DO ZELO: preciso de ajuda. Esta é apenas uma prévia de como seria um pedido de ajuda.',
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No pedido real, a localização pode ser incluída quando disponível.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'WhatsApp e e-mail não serão abertos nesta demonstração.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 20),
                        const _DemoExplanation(
                          icon: Icons.verified_user_outlined,
                          title: 'Experiência concluída com segurança',
                          message:
                              'Nenhum sensor foi ativado e nenhum registro foi salvo no histórico ou na nuvem.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Experimentar outra resposta'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => context.go('/inicio'),
                          child: const Text('Concluir demonstração'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (data.unresolved != null && introduction) ...[
                const SizedBox(height: 16),
                StatusPanel(
                  title: 'Você tem um registro para revisar',
                  message:
                      'Uma ocorrência anterior ainda não foi marcada como resolvida. A simulação não altera esse registro.',
                  icon: Icons.history_rounded,
                  tone: AppTone.warning,
                ),
                TextButton(
                  onPressed: () => context.push(
                    '/historico/incidents/${data.unresolved!.id}',
                  ),
                  child: const Text('Revisar ocorrência'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Esta demonstração explica o fluxo de resposta. Ela não testa a detecção de acidentes nem o funcionamento dos sensores.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DemoExplanation extends StatelessWidget {
  const _DemoExplanation({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}
