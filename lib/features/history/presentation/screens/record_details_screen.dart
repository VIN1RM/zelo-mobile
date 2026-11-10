import '../../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/data/zelo_repository.dart';
import '../../../../core/database/local_store.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../data/attachment_store.dart';
import '../../../monitoring/domain/monitoring_session.dart';

class RecordDetailsScreen extends StatefulWidget {
  const RecordDetailsScreen({required this.type, required this.id, super.key});
  final String type;
  final String id;
  @override
  State<RecordDetailsScreen> createState() => _RecordDetailsScreenState();
}

class _RecordDetailsScreenState extends State<RecordDetailsScreen> {
  final _guard = GlobalKey<UnsavedChangesGuardState>();
  final notes = TextEditingController();
  bool initialized = false;
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final incident = data.incidents
          .where((i) => i.id == widget.id)
          .firstOrNull;
      final session = data.sessions.where((s) => s.id == widget.id).firstOrNull;
      if (!const ['incidents', 'sessions'].contains(widget.type) ||
          widget.type == 'incidents' && incident == null ||
          widget.type == 'sessions' && session == null) {
        return Scaffold(
          appBar: AppHeader(title: const Text('Detalhes')),
          body: const Center(
            child: Text('Registro não encontrado nesta conta.'),
          ),
        );
      }
      if (!initialized) {
        notes.text = incident?.notes ?? '';
        initialized = true;
      }
      final location = incident?.location ?? session?.location;
      return UnsavedChangesGuard(
        key: _guard,
        controllers: [notes],
        child: Scaffold(
          appBar: AppHeader(title: const Text('Detalhes do registro')),
          body: OrganizedListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionHeading(
                incident?.label ?? 'Trajeto',
                subtitle: dateLabel(incident?.occurredAt ?? session!.startedAt),
              ),
              StatusPanel(
                title: outcomeLabel(incident?.outcome ?? session!.status),
                message: incident == null
                    ? 'Confira os detalhes deste trajeto abaixo.'
                    : 'Este é o resultado original do alerta. Você pode atualizar sua condição sem alterar este registro.',
                icon: incident == null
                    ? AppIcons.twoWheelerRounded
                    : AppIcons.shieldOutlined,
              ),
              const SizedBox(height: 20),
              if (session != null) ...[
                SwitchListTile(
                  title: const Text('Preservar trajeto'),
                  value: session.preserved,
                  onChanged: data.busy
                      ? null
                      : (value) => uiAction(
                          context,
                          () => app.operation(
                            () => app.repository.preserveSession(
                              session.id,
                              value,
                            ),
                          ),
                        ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.phoneAndroidRounded),
                  title: const Text('Posi\u00e7\u00e3o do celular'),
                  subtitle: Text(session.position.label),
                ),
                if (session.endedAt != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.history),
                    title: const Text('Fim do trajeto'),
                    subtitle: Text(dateLabel(session.endedAt!)),
                  ),
              ],
              const SectionHeading('Localização registrada'),
              Text(
                location?.describe(DateTime.now().toUtc()) ??
                    'Localização indisponível.',
              ),
              if (location != null) SelectableText(location.mapUrl),
              if (incident != null) ...[
                const SizedBox(height: 16),
                const SectionHeading('Como você está agora?'),
                Text(
                  'Condição atual: ${outcomeLabel(incident.condition)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                ResponsiveActions(
                  children: [
                    OutlinedButton.icon(
                      onPressed: data.busy || incident.condition == 'SAFE'
                          ? null
                          : () => uiAction(
                              context,
                              () => app.updateCondition(incident.id, 'SAFE'),
                            ),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                      ),
                      label: const Text('Estou bem'),
                    ),
                    OutlinedButton.icon(
                      onPressed: data.busy || incident.condition == 'NEEDS_HELP'
                          ? null
                          : () => uiAction(
                              context,
                              () => app.updateCondition(
                                incident.id,
                                'NEEDS_HELP',
                              ),
                            ),
                      icon: const Icon(Icons.support_agent_rounded, size: 20),
                      label: const Text('Preciso de ajuda'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sua condição pode mudar. As atualizações preservam o resultado original do alerta.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: data.busy
                      ? null
                      : () => context.push('/ajuda/${incident.id}'),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Abrir pedido de ajuda'),
                ),
                const SizedBox(height: 16),
                const SectionHeading(
                  'Suas observações',
                  subtitle: 'Estas informações ficam somente no aparelho.',
                ),
                TextField(
                  controller: notes,
                  enabled: !data.busy,
                  maxLength: 4000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observações locais',
                  ),
                ),
                SaveChangesButton(
                  guard: _guard,
                  busy: data.busy,
                  outlined: true,
                  onPressed: data.busy
                      ? null
                      : () async {
                          final saved = await uiAction(
                            context,
                            () => app.operation(
                              () => app.repository.updateIncident(
                                incident.id,
                                notes: notes.text,
                              ),
                            ),
                            success: 'Observações salvas no aparelho.',
                          );
                          if (saved) await _guard.currentState?.acceptChanges();
                        },
                  label: 'Salvar observa\u00e7\u00f5es',
                ),
                SwitchListTile(
                  title: const Text('Preservar ocorrência'),
                  subtitle: const Text(
                    'Impede remoção automática por retenção.',
                  ),
                  value: incident.preserved,
                  onChanged: data.busy
                      ? null
                      : (value) => uiAction(
                          context,
                          () => app.operation(
                            () => app.repository.updateIncident(
                              incident.id,
                              preserved: value,
                            ),
                          ),
                        ),
                ),
                FutureBuilder(
                  future: app.repository.rows('updates'),
                  builder: (context, snapshot) {
                    final updates = (snapshot.data ?? [])
                        .map(LocalStore.decode)
                        .where((u) => u['incidentId'] == incident.id)
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeading(
                          'Atualiza\u00e7\u00f5es de condi\u00e7\u00e3o',
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Carregando atualiza\u00e7\u00f5es',
                          ),
                        if (snapshot.hasError)
                          const Text(
                            'N\u00e3o foi poss\u00edvel carregar as atualiza\u00e7\u00f5es.',
                          ),
                        if (snapshot.hasData && updates.isEmpty)
                          const Text(
                            'Nenhuma atualiza\u00e7\u00e3o de condi\u00e7\u00e3o registrada.',
                          ),
                        for (final update in updates)
                          ListTile(
                            title: Text(
                              outcomeLabel(update['condition'] as String),
                            ),
                            subtitle: Text(
                              dateLabel(
                                DateTime.fromMillisecondsSinceEpoch(
                                  update['createdAt'] as int,
                                  isUtc: true,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const SectionHeading(
                  'Fotos da ocorrência',
                  subtitle: 'Protegidas e salvas somente neste aparelho.',
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: data.busy
                          ? null
                          : () => uiAction(
                              context,
                              () => app.operation(
                                () => AttachmentStore(
                                  app.repository,
                                ).add(incident.id, ImageSource.camera),
                              ),
                            ),
                      icon: const Icon(AppIcons.cameraAltOutlined),
                      label: const Text('Tirar foto'),
                    ),
                    TextButton.icon(
                      onPressed: data.busy
                          ? null
                          : () => uiAction(
                              context,
                              () => app.operation(
                                () => AttachmentStore(
                                  app.repository,
                                ).add(incident.id, ImageSource.gallery),
                              ),
                            ),
                      icon: const Icon(AppIcons.photoLibraryOutlined),
                      label: const Text('Escolher foto'),
                    ),
                  ],
                ),
                FutureBuilder(
                  future: AttachmentStore(app.repository).list(incident.id),
                  builder: (context, snapshot) => Column(
                    children: [
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Carregando fotos',
                        ),
                      if (snapshot.hasError)
                        const Text(
                          'N\u00e3o foi poss\u00edvel abrir as fotos neste aparelho.',
                        ),
                      if (snapshot.hasData && snapshot.data!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Nenhuma foto adicionada.'),
                        ),
                      for (final row in snapshot.data ?? [])
                        _Photo(
                          key: ValueKey(row['id']),
                          row: row,
                          repository: app.repository,
                          onRemove: () => uiAction(
                            context,
                            () => app.operation(
                              () => AttachmentStore(app.repository).remove(row),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                FutureBuilder(
                  future: app.repository.store.db.query(
                    'share_attempts',
                    where: 'user_id=? AND incident_id=?',
                    whereArgs: [app.repository.uid, incident.id],
                  ),
                  builder: (context, snapshot) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tentativas de compartilhamento — sem confirmação de envio',
                      ),
                      for (final row in snapshot.data ?? [])
                        Text(
                          '${channelLabel((jsonDecode(row['payload'] as String) as Map)['channel'])} • ${shareStateLabel((jsonDecode(row['payload'] as String) as Map)['status'])}',
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => uiAction(context, () async {
                  await SharePlus.instance.share(
                    ShareParams(
                      text:
                          '${incident?.label ?? 'Trajeto'}\nData: ${dateLabel(incident?.occurredAt ?? session!.startedAt)}\nSituação: ${outcomeLabel(incident?.outcome ?? session!.status)}\n${incident == null ? 'Posição: ${session!.position.label}' : 'Condição atual: ${outcomeLabel(incident.condition)}'}\n${location?.describe(DateTime.now().toUtc()) ?? 'Localização indisponível.'}\n${location?.mapUrl ?? ''}\n${incident?.notes ?? ''}',
                      subject: 'ZELO — exportação de registro',
                    ),
                  );
                }),
                icon: const Icon(AppIcons.iosShare),
                label: const Text('Exportar registro'),
              ),
              TextButton.icon(
                onPressed: data.busy
                    ? null
                    : () async {
                        if (await confirmAction(
                              context,
                              'Excluir registro?',
                              'A exclusão local será imediata; a remoção na nuvem exige confirmação posterior. Fotos locais serão removidas. A ação não pode ser desfeita.',
                            ) &&
                            context.mounted) {
                          if (await uiAction(
                                context,
                                () => app.deleteRecord(widget.type, widget.id),
                              ) &&
                              context.mounted) {
                            context.go('/historico');
                          }
                        }
                      },
                icon: const Icon(AppIcons.deleteOutline),
                label: const Text('Excluir registro'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Photo extends StatefulWidget {
  const _Photo({
    required this.row,
    required this.repository,
    required this.onRemove,
    super.key,
  });
  final Map<String, Object?> row;
  final ZeloRepository repository;
  final VoidCallback onRemove;
  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  late final Future<Uint8List> bytes = AttachmentStore(
    widget.repository,
  ).read(widget.row);
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        FutureBuilder(
          future: bytes,
          builder: (context, snapshot) => snapshot.hasData
              ? Image.memory(snapshot.data!, height: 200, fit: BoxFit.contain)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.hasError
                        ? 'Foto indisponível neste aparelho.'
                        : 'Abrindo foto protegida…',
                  ),
                ),
        ),
        TextButton(
          onPressed: () async {
            if (await confirmAction(
              context,
              'Excluir foto?',
              'Esta foto será removida deste aparelho.',
            )) {
              widget.onRemove();
            }
          },
          child: const Text('Excluir foto'),
        ),
      ],
    ),
  );
}
