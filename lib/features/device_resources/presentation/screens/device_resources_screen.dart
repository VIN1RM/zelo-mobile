import '../../../../shared/widgets/app_header.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/platform/device_permissions.dart';
import '../../../../shared/presentation/app_icons.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../emergency/domain/location_snapshot.dart';
import '../../data/device_resources_gateway.dart';
import '../../domain/acceleration_reading.dart';

class DeviceResourcesScreen extends ConsumerStatefulWidget {
  const DeviceResourcesScreen({super.key});
  @override
  ConsumerState<DeviceResourcesScreen> createState() =>
      _DeviceResourcesScreenState();
}

class _DeviceResourcesScreenState extends ConsumerState<DeviceResourcesScreen>
    with WidgetsBindingObserver {
  late Stream<AccelerationReading> _acceleration;
  bool _visible = true;
  bool _cameraBusy = false;
  bool _locationBusy = false;
  bool _notificationBusy = false;
  Uint8List? _photo;
  String? _photoMessage;
  String? _notificationMessage;
  LocationSnapshot? _location;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _acceleration = ref
        .read(deviceResourcesGatewayProvider)
        .watchAcceleration();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (visible == _visible || !mounted) return;
    setState(() {
      _visible = visible;
      if (visible) {
        _acceleration = ref
            .read(deviceResourcesGatewayProvider)
            .watchAcceleration();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    setState(() => _cameraBusy = true);
    try {
      await uiAction(context, () async {
        final photo = await ref
            .read(deviceResourcesGatewayProvider)
            .takePhoto();
        if (!mounted) return;
        setState(() {
          if (photo != null) _photo = photo;
          _photoMessage = photo == null
              ? 'Captura cancelada. Você pode tentar novamente.'
              : 'Foto capturada pela câmera e exibida abaixo.';
        });
      });
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  Future<void> _locate() async {
    setState(() => _locationBusy = true);
    try {
      await uiAction(context, () async {
        final location = await ref
            .read(deviceResourcesGatewayProvider)
            .locate();
        if (mounted) setState(() => _location = location);
      });
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _notify() async {
    setState(() {
      _notificationBusy = true;
      _notificationMessage = null;
    });
    final success = await uiAction(
      context,
      () => ref.read(deviceResourcesGatewayProvider).notify(),
    );
    if (!mounted) return;
    if (!success) {
      setState(() => _notificationBusy = false);
      return;
    }
    setState(
      () => _notificationMessage =
          'Teste agendado para daqui a 5 segundos. Você pode bloquear a tela agora.',
    );
    _notificationTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _notificationBusy = false;
          _notificationMessage =
              'Abra a barra de notificações e procure “TESTE DO ZELO”. Som, vibração e exibição sobre a tela dependem das configurações do Android.';
        });
      }
    });
  }

  String _number(double value, [int digits = 2]) =>
      value.toStringAsFixed(digits).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppHeader(title: const Text('Recursos do aparelho')),
    body: AppScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const SectionHeading(
          'Seu smartphone inteligente',
          subtitle:
              'Explore câmera, localização, notificação local e acelerômetro no tema de segurança do ZELO.',
        ),
        const StatusPanel(
          title: 'Uma demonstração segura',
          message:
              'Esta tela não inicia a proteção, não registra emergências e não envia mensagens. Foto e coordenadas ficam apenas nesta tela, sem sincronização.',
          icon: AppIcons.infoOutlineRounded,
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ResourceHeading(
                number: '1',
                icon: AppIcons.cameraAltOutlined,
                title: 'Câmera',
                description:
                    'Capture uma foto para demonstrar um registro visual do trajeto.',
              ),
              if (_photo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _photo!,
                    height: 240,
                    fit: BoxFit.contain,
                    semanticLabel:
                        'Fotografia capturada pela câmera do aparelho',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_photoMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_photoMessage!),
                ),
              FilledButton.icon(
                onPressed: _cameraBusy ? null : _takePhoto,
                icon: const Icon(AppIcons.cameraAltOutlined),
                label: LoadingLabel(
                  loading: _cameraBusy,
                  label: _photo == null ? 'Tirar foto' : 'Tirar outra foto',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A foto é temporária. Ao sair desta tela, a prévia não fica no histórico.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ResourceHeading(
                number: '2',
                icon: AppIcons.locationOnOutlined,
                title: 'Localização GPS',
                description:
                    'Obtenha as coordenadas atuais para orientar um pedido de ajuda.',
              ),
              if (_location != null) ...[
                _ValueRow(
                  label: 'Latitude',
                  value: '${_number(_location!.latitude, 6)}°',
                ),
                _ValueRow(
                  label: 'Longitude',
                  value: '${_number(_location!.longitude, 6)}°',
                ),
                const SizedBox(height: 8),
                Text(_location!.describe(DateTime.now().toUtc())),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => uiAction(context, () async {
                        if (!await launchUrl(
                          Uri.parse(_location!.mapUrl),
                          mode: LaunchMode.externalApplication,
                        )) {
                          throw const FormatException('Mapa indisponível.');
                        }
                      }),
                      icon: const Icon(AppIcons.openInNewRounded),
                      label: const Text('Abrir no mapa'),
                    ),
                    TextButton.icon(
                      onPressed: () => uiAction(
                        context,
                        () => Clipboard.setData(
                          ClipboardData(
                            text:
                                'Latitude: ${_number(_location!.latitude, 6)}\nLongitude: ${_number(_location!.longitude, 6)}\n${_location!.mapUrl}',
                          ),
                        ),
                        success: 'Coordenadas copiadas.',
                      ),
                      icon: const Icon(AppIcons.copy),
                      label: const Text('Copiar coordenadas'),
                    ),
                  ],
                ),
              ],
              FilledButton.icon(
                onPressed: _locationBusy ? null : _locate,
                icon: const Icon(AppIcons.locationOnOutlined),
                label: LoadingLabel(
                  loading: _locationBusy,
                  label: _location == null
                      ? 'Obter coordenadas'
                      : 'Atualizar coordenadas',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ResourceHeading(
                number: '3',
                icon: AppIcons.notificationsOutlined,
                title: 'Notificação local',
                description:
                    'Exiba um aviso de teste pelo próprio Android, sem depender de internet.',
              ),
              FilledButton.icon(
                onPressed: _notificationBusy ? null : _notify,
                icon: const Icon(AppIcons.notificationsOutlined),
                label: LoadingLabel(
                  loading: _notificationBusy,
                  label: 'Testar notificação em 5 segundos',
                ),
              ),
              if (_notificationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_notificationMessage!),
                ),
              const SizedBox(height: 12),
              const Text(
                'O aviso é identificado como TESTE. Ele não aciona o detector, o contador de emergência nem os seus contatos.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ResourceHeading(
                number: '4',
                icon: AppIcons.sensorsRounded,
                title: 'Acelerômetro ao vivo',
                description:
                    'Incline o aparelho suavemente e acompanhe os três eixos. Não é preciso arremessar ou bater o celular.',
              ),
              StreamBuilder<AccelerationReading>(
                stream: _visible ? _acceleration : null,
                builder: (context, snapshot) {
                  if (!_visible) {
                    return const Text(
                      'Leitura pausada enquanto esta tela está em segundo plano.',
                    );
                  }
                  if (snapshot.hasError ||
                      snapshot.connectionState == ConnectionState.done) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const StatusPanel(
                          title: 'Acelerômetro indisponível',
                          message:
                              'Este aparelho pode não oferecer o sensor ou a leitura foi interrompida. Nenhum valor é simulado.',
                          icon: AppIcons.infoOutlineRounded,
                          tone: AppTone.warning,
                        ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _acceleration = ref
                                .read(deviceResourcesGatewayProvider)
                                .watchAcceleration(),
                          ),
                          icon: const Icon(AppIcons.refresh),
                          label: const Text('Tentar leitura novamente'),
                        ),
                      ],
                    );
                  }
                  final value = snapshot.data;
                  if (value == null ||
                      snapshot.connectionState != ConnectionState.active) {
                    return const Text(
                      'Aguardando a primeira leitura real do sensor…',
                    );
                  }
                  return Column(
                    children: [
                      _ValueRow(
                        label: 'Eixo X',
                        value: '${_number(value.x)} m/s²',
                      ),
                      _ValueRow(
                        label: 'Eixo Y',
                        value: '${_number(value.y)} m/s²',
                      ),
                      _ValueRow(
                        label: 'Eixo Z',
                        value: '${_number(value.z)} m/s²',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'As leituras incluem a gravidade. Com o celular parado, um dos eixos pode ficar próximo de 9,8 m/s². Esta visualização pausa ao sair da tela; a proteção iniciada no início usa um serviço separado.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppActionTile(
          icon: AppIcons.settingsOutlined,
          title: 'Permissões do aplicativo',
          subtitle: 'Revise câmera, localização e notificações no Android',
          external: true,
          onTap: () => uiAction(context, DevicePermissions.openSettings),
        ),
      ],
    ),
  );
}

class _ResourceHeading extends StatelessWidget {
  const _ResourceHeading({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });
  final String number;
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon),
        const SizedBox(height: 12),
        SectionHeading('$number. $title', subtitle: description),
      ],
    ),
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 6,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        SelectableText(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}
