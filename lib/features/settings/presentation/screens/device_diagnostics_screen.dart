import '../../../../shared/widgets/app_components.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/diagnostics_provider.dart';

class DeviceDiagnosticsScreen extends ConsumerStatefulWidget {
  const DeviceDiagnosticsScreen({super.key});

  @override
  ConsumerState<DeviceDiagnosticsScreen> createState() =>
      _DeviceDiagnosticsScreenState();
}

class _DeviceDiagnosticsScreenState
    extends ConsumerState<DeviceDiagnosticsScreen>
    with WidgetsBindingObserver {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(deviceDiagnosticsProvider);
    }
  }

  Future<void> _openNotifications() async {
    try {
      await ref.read(diagnosticsGatewayProvider).openNotificationSettings();
    } on PlatformException {
      _showSettingsError();
    } on MissingPluginException {
      _showSettingsError();
    }
  }

  void _showSettingsError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir os ajustes Android.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = ref.watch(deviceDiagnosticsProvider);
    return Scaffold(
      appBar: AppHeader(title: const Text('Diagnóstico do aparelho')),
      body: OrganizedListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeading(
            'Confira os recursos do celular',
            subtitle:
                'Veja as permissões e os sensores disponíveis para o ZELO.',
          ),
          const Text(
            'Esta consulta não coleta movimentos nem localização. '
            'Recursos disponíveis não confirmam proteção ativa.',
          ),
          const SizedBox(height: 16),
          diagnostics.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Não foi possível consultar o aparelho. '
                  'Este diagnóstico está disponível no aplicativo Android.',
                ),
              ),
            ),
            data: (data) => Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Versão Android'),
                    subtitle: Text('API ${data.androidApi}'),
                  ),
                  _DiagnosticRow(
                    title: 'Acelerômetro',
                    value: data.accelerometerAvailable
                        ? 'Disponível'
                        : 'Indisponível',
                  ),
                  _DiagnosticRow(
                    title: 'Giroscópio',
                    value: data.gyroscopeAvailable
                        ? 'Disponível'
                        : 'Indisponível',
                  ),
                  _DiagnosticRow(
                    title: 'Notificações',
                    value: data.notificationsEnabled
                        ? 'Permitidas pelo sistema'
                        : 'Não permitidas pelo sistema',
                  ),
                  _DiagnosticRow(
                    title: 'Otimização de bateria',
                    value: data.batteryOptimizationExempt
                        ? 'Aplicativo isento'
                        : 'Aplicada pelo sistema',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeading('Permissões e ajustes'),
          OutlinedButton.icon(
            onPressed: diagnostics.isLoading
                ? null
                : () => ref.invalidate(deviceDiagnosticsProvider),
            icon: const Icon(AppIcons.refresh),
            label: const Text('Atualizar diagnóstico'),
          ),
          if (diagnostics.hasValue)
            TextButton(
              onPressed: _openNotifications,
              child: const Text('Abrir ajustes de notificações'),
            ),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text(title), subtitle: Text(value));
}
