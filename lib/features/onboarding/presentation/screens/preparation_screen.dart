import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/platform/device_permissions.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../settings/presentation/providers/diagnostics_provider.dart';
import '../providers/readiness_provider.dart';

class PreparationScreen extends ConsumerStatefulWidget {
  const PreparationScreen({super.key});
  @override
  ConsumerState<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends ConsumerState<PreparationScreen>
    with WidgetsBindingObserver {
  bool fixing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void refresh() {
    ref.invalidate(deviceDiagnosticsProvider);
    ref.invalidate(preparationReadinessProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> fix(Future<void> Function() action) async {
    if (fixing) return;
    setState(() => fixing = true);
    await uiAction(context, action);
    if (!mounted) return;
    setState(() => fixing = false);
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final readiness = ref.watch(preparationReadinessProvider);
    return AppView(
      builder: (context, data, app) {
        final checks = readiness.asData?.value;
        final contactsReady = data.contacts.isNotEmpty;
        final notificationsReady = checks?.device.notificationsEnabled == true;
        final sensorsReady = checks?.sensorsReady == true;
        final completed = [
          contactsReady,
          notificationsReady,
          sensorsReady,
        ].where((value) => value).length;
        final busy = data.busy || fixing;
        return Scaffold(
          appBar: const AppHeader(title: Text('Preparar prote\u00e7\u00e3o')),
          body: AppScrollView(
            children: [
              const SectionHeading(
                'Vamos deixar tudo pronto',
                subtitle:
                    'Confira os requisitos antes de sair. A prote\u00e7\u00e3o s\u00f3 come\u00e7a quando voc\u00ea iniciar no in\u00edcio.',
              ),
              StatusPanel(
                title: '$completed de 3 requisitos prontos',
                message: completed == 3
                    ? 'Voc\u00ea pode concluir a prepara\u00e7\u00e3o. Confira tamb\u00e9m as recomenda\u00e7\u00f5es abaixo.'
                    : 'Resolva os itens pendentes para concluir a prepara\u00e7\u00e3o.',
                icon: completed == 3
                    ? Icons.check_circle_outline
                    : Icons.fact_check_outlined,
                tone: completed == 3 ? AppTone.positive : AppTone.warning,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: completed / 3,
                semanticsLabel: '$completed de 3 requisitos prontos',
              ),
              const SizedBox(height: 20),
              _CheckItem(
                title: 'Contatos de confian\u00e7a',
                ready: contactsReady,
                message: contactsReady
                    ? '${data.contacts.length} contatos cadastrados.'
                    : 'Cadastre pelo menos uma pessoa de confian\u00e7a.',
                action: 'Gerenciar contatos',
                onPressed: busy ? null : () => context.push('/contatos'),
              ),
              readiness.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Verificando aparelho',
                    ),
                  ),
                ),
                error: (error, stack) => AppEmptyState(
                  icon: Icons.settings_outlined,
                  title: 'N\u00e3o foi poss\u00edvel verificar o aparelho',
                  message:
                      'Tente novamente para consultar os recursos e as permiss\u00f5es atuais.',
                  action: OutlinedButton(
                    onPressed: refresh,
                    child: const Text('Verificar novamente'),
                  ),
                ),
                data: (check) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CheckItem(
                      title: 'Notifica\u00e7\u00f5es',
                      ready: notificationsReady,
                      message: notificationsReady
                          ? 'Permiss\u00e3o concedida pelo Android.'
                          : 'Permita as notifica\u00e7\u00f5es para receber os alertas.',
                      action: notificationsReady
                          ? 'Revisar permiss\u00e3o'
                          : 'Permitir notifica\u00e7\u00f5es',
                      onPressed: busy
                          ? null
                          : () => fix(() async {
                              if (notificationsReady ||
                                  !await DevicePermissions.requestNotifications()) {
                                await DevicePermissions.openSettings();
                              }
                            }),
                    ),
                    _CheckItem(
                      title: 'Sensores de movimento',
                      ready: sensorsReady,
                      message: sensorsReady
                          ? 'Aceler\u00f4metro e girosc\u00f3pio dispon\u00edveis.'
                          : 'Um ou mais sensores necess\u00e1rios est\u00e3o indispon\u00edveis neste aparelho.',
                      action: 'Ver diagn\u00f3stico',
                      onPressed: busy
                          ? null
                          : () => context.push('/ajustes/diagnostico'),
                    ),
                    const SectionHeading(
                      'Recomenda\u00e7\u00f5es',
                      subtitle:
                          'Estes itens n\u00e3o impedem a prepara\u00e7\u00e3o.',
                    ),
                    _CheckItem(
                      title: 'Localiza\u00e7\u00e3o pontual',
                      ready: check.locationReady,
                      message: check.locationReady == true
                          ? 'Permiss\u00e3o e localiza\u00e7\u00e3o do aparelho dispon\u00edveis.'
                          : 'A localiza\u00e7\u00e3o melhora a mensagem de ajuda. Sem GPS, o monitoramento local continua.',
                      action: 'Revisar localiza\u00e7\u00e3o',
                      onPressed: busy
                          ? null
                          : () => fix(() async {
                              final permission =
                                  await Geolocator.requestPermission();
                              if (permission ==
                                  LocationPermission.deniedForever) {
                                await Geolocator.openAppSettings();
                              } else if (!await Geolocator.isLocationServiceEnabled()) {
                                await Geolocator.openLocationSettings();
                              }
                            }),
                    ),
                    _CheckItem(
                      title: 'Bateria em segundo plano',
                      ready: check.device.batteryOptimizationExempt,
                      message: check.device.batteryOptimizationExempt
                          ? 'O aplicativo est\u00e1 isento de otimiza\u00e7\u00e3o de bateria.'
                          : 'O Android pode limitar a atividade. Revise a bateria se houver interrup\u00e7\u00f5es.',
                      action: 'Abrir ajustes',
                      onPressed: busy
                          ? null
                          : () => fix(DevicePermissions.openSettings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escolha Bolso ou Suporte no in\u00edcio. A disponibilidade de recursos n\u00e3o confirma prote\u00e7\u00e3o ativa. A detec\u00e7\u00e3o \u00e9 experimental.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy || completed != 3
                    ? null
                    : () async {
                        if (await uiAction(context, app.prepare) &&
                            context.mounted) {
                          context.go('/inicio');
                        }
                      },
                child: LoadingLabel(
                  loading: data.busy,
                  label: 'Concluir prepara\u00e7\u00e3o',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.title,
    required this.ready,
    required this.message,
    required this.action,
    required this.onPressed,
  });
  final String title;
  final bool? ready;
  final String message;
  final String action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              ready == true ? Icons.check_circle_outline : Icons.info_outline,
              color: (ready == true ? AppTone.positive : AppTone.warning)
                  .foregroundFor(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          ready == null
              ? 'N\u00e3o foi poss\u00edvel verificar este item. $message'
              : '${ready! ? 'Pronto' : 'Pendente'} \u00b7 $message',
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}
