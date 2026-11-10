import '../../../../shared/widgets/app_header.dart';
import 'dart:async';
import '../../../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_view.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});
  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  Timer? timer;
  DateTime? deadline;
  String message = 'Experimente o alerta antes de precisar dele.';
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void resolve(String value) {
    timer?.cancel();
    setState(() {
      deadline = null;
      message = value;
    });
  }

  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      if (data.session != null ||
          data.alert != null ||
          data.unresolved != null) {
        return Scaffold(
          appBar: AppHeader(title: const Text('Demonstração')),
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Encerre a sessão e resolva alertas reais antes de usar a demonstração.',
            ),
          ),
        );
      }
      final remaining = deadline == null
          ? 0
          : (deadline!.difference(DateTime.now()).inMilliseconds / 1000)
                .ceil()
                .clamp(0, 30);
      return Scaffold(
        appBar: AppHeader(title: const Text('DEMONSTRAÇÃO')),
        body: OrganizedListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SectionHeading(
              'Conheça o fluxo de ajuda',
              subtitle:
                  '1. Simule um movimento suspeito. 2. Responda ao alerta. 3. Veja o resultado.',
            ),
            const Text(
              'SIMULAÇÃO — NÃO É UMA EMERGÊNCIA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Este fluxo não usa sensores, não envia mensagens e não grava no histórico ou na sincronização.',
            ),
            const SizedBox(height: 24),
            if (deadline != null) ...[
              AlertCountdown(seconds: remaining),
              const SizedBox(height: 24),
            ],
            StatusPanel(
              icon: AppIcons.infoOutlineRounded,
              title: deadline == null
                  ? 'Pronto para experimentar'
                  : 'Você está bem?',
              message: deadline == null
                  ? message
                  : 'Responda em $remaining segundos. Sem resposta, um pedido de ajuda será simulado.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: deadline != null
                  ? null
                  : () {
                      setState(
                        () => deadline = DateTime.now().add(
                          const Duration(seconds: 30),
                        ),
                      );
                      timer = Timer.periodic(const Duration(milliseconds: 250), (
                        _,
                      ) {
                        if (deadline != null &&
                            !deadline!.isAfter(DateTime.now())) {
                          resolve(
                            'Tempo encerrado. Ajuda simulada preparada. Nenhuma mensagem enviada.',
                          );
                        } else if (mounted) {
                          setState(() {});
                        }
                      });
                    },
              child: const Text('Simular possível acidente'),
            ),
            TextButton(
              onPressed: deadline == null
                  ? null
                  : () =>
                        resolve('Alerta simulado cancelado. Nada foi gravado.'),
              child: const Text('Estou bem'),
            ),
            TextButton(
              onPressed: deadline == null
                  ? null
                  : () => resolve(
                      'Pedido de ajuda simulado. Nenhum canal real será aberto.',
                    ),
              child: const Text('Preciso de ajuda'),
            ),
          ],
        ),
      );
    },
  );
}
