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

class RecordDetailsScreen extends StatefulWidget {
  const RecordDetailsScreen({required this.type, required this.id, super.key});
  final String type;
  final String id;
  @override
  State<RecordDetailsScreen> createState() => _RecordDetailsScreenState();
}

class _RecordDetailsScreenState extends State<RecordDetailsScreen> {
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
          appBar: AppBar(title: const Text('Detalhes')),
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
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes do registro')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              incident?.label ?? 'Trajeto',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(dateLabel(incident?.occurredAt ?? session!.startedAt)),
            Text(outcomeLabel(incident?.outcome ?? session!.status)),
            if (session != null) ...[
              SwitchListTile(
                title: const Text('Preservar trajeto'),
                value: session.preserved,
                onChanged: data.busy
                    ? null
                    : (value) => uiAction(
                        context,
                        () => app.operation(
                          () =>
                              app.repository.preserveSession(session.id, value),
                        ),
                      ),
              ),
              Text('Posição: ${session.position.name}'),
              if (session.endedAt != null)
                Text('Fim: ${dateLabel(session.endedAt!)}'),
            ],
            Text(
              location?.describe(DateTime.now().toUtc()) ??
                  'Localização indisponível.',
            ),
            if (location != null) SelectableText(location.mapUrl),
            if (incident != null) ...[
              const SizedBox(height: 16),
              Text('Condição atual: ${outcomeLabel(incident.condition)}'),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: data.busy
                        ? null
                        : () => uiAction(
                            context,
                            () => app.updateCondition(incident.id, 'SAFE'),
                          ),
                    child: const Text('Estou bem'),
                  ),
                  OutlinedButton(
                    onPressed: data.busy
                        ? null
                        : () => uiAction(
                            context,
                            () =>
                                app.updateCondition(incident.id, 'NEEDS_HELP'),
                          ),
                    child: const Text('Preciso de ajuda'),
                  ),
                ],
              ),
              const Text(
                'Atualizações posteriores não alteram o resultado original do alerta.',
              ),
              TextButton(
                onPressed: () => context.push('/ajuda/${incident.id}'),
                child: const Text('Abrir pedido de ajuda'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notes,
                maxLength: 4000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observações locais',
                ),
              ),
              OutlinedButton(
                onPressed: data.busy
                    ? null
                    : () => uiAction(
                        context,
                        () => app.operation(
                          () => app.repository.updateIncident(
                            incident.id,
                            notes: notes.text,
                          ),
                        ),
                        success: 'Observações salvas no aparelho.',
                      ),
                child: const Text('Salvar observações'),
              ),
              SwitchListTile(
                title: const Text('Preservar ocorrência'),
                subtitle: const Text('Impede remoção automática por retenção.'),
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
                      const Text('Atualizações de condição'),
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
              const Text('Fotos ficam criptografadas somente neste aparelho.'),
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
                    icon: const Icon(Icons.camera_alt_outlined),
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
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Escolher foto'),
                  ),
                ],
              ),
              FutureBuilder(
                future: AttachmentStore(app.repository).list(incident.id),
                builder: (context, snapshot) => Column(
                  children: [
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
                        '${(jsonDecode(row['payload'] as String) as Map)['channel']} • ${(jsonDecode(row['payload'] as String) as Map)['status']}',
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
                    text: jsonEncode(incident?.toJson() ?? session!.toJson()),
                    subject: 'ZELO — exportação de registro',
                  ),
                );
              }),
              icon: const Icon(Icons.ios_share),
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
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir registro'),
            ),
          ],
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
