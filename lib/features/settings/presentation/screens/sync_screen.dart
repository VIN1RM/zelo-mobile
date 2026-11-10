import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/presentation/app_icons.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../shared/widgets/app_view.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool syncing = false;
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) => Scaffold(
      appBar: AppHeader(title: const Text('Sincronização')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          StatusPanel(
            title: data.pendingSync == 0
                ? 'Nenhum envio pendente'
                : 'Seus dados estão salvos no aparelho',
            message:
                data.notice ??
                'A sincronização acontece automaticamente com o app aberto e acesso à internet.',
            icon: data.pendingSync == 0
                ? AppIcons.cloudDoneOutlined
                : AppIcons.cloudUploadOutlined,
            tone: data.pendingSync == 0 ? AppTone.neutral : AppTone.warning,
          ),
          const SizedBox(height: 16),
          const Text(
            'A sincronização é automática. Use o botão abaixo para antecipar uma tentativa.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: data.busy || syncing
                ? null
                : () async {
                    setState(() => syncing = true);
                    try {
                      await uiAction(context, () async {
                        await app.sync();
                      });
                    } finally {
                      if (mounted) setState(() => syncing = false);
                    }
                  },
            icon: syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.sync),
            label: Text(syncing ? 'Sincronizando…' : 'Sincronizar agora'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Se o mesmo registro mudar em outro aparelho, você poderá revisar qual versão manter. Fotos e observações ficam somente neste aparelho.',
          ),
          FutureBuilder(
            future: app.repository.store.db.rawQuery(
              'SELECT o.*,r.is_deleted,r.payload FROM outbox o JOIN records r ON o.user_id=r.user_id AND o.entity_type=r.entity_type AND o.entity_id=r.id WHERE o.user_id=?',
              [app.repository.uid],
            ),
            builder: (context, snapshot) => snapshot.hasError
                ? const StatusPanel(
                    title: 'Não foi possível consultar os envios',
                    message:
                        'Volte a esta tela para tentar novamente. Seus registros continuam salvos.',
                    icon: AppIcons.infoOutline,
                    tone: AppTone.warning,
                  )
                : !snapshot.hasData &&
                      snapshot.connectionState == ConnectionState.waiting
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Consultando sincronização',
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final row in snapshot.data ?? [])
                        Card(
                          child: ListTile(
                            leading: IconBadge(
                              row['status'] == 'DENIED'
                                  ? AppIcons.lockOutline
                                  : row['status'] == 'CONFLICT'
                                  ? AppIcons.compareArrowsRounded
                                  : AppIcons.cloudUploadOutlined,
                              tone: row['status'] == 'PENDING'
                                  ? AppTone.neutral
                                  : AppTone.warning,
                            ),
                            title: Text(
                              row['entity_type'] == 'contacts' &&
                                      row['is_deleted'] != 1
                                  ? '${(jsonDecode(row['payload'] as String) as Map)['name'] ?? 'Contato de emergência'}'
                                  : entityLabel(row['entity_type']),
                            ),
                            subtitle: Text(
                              '${syncStateLabel(row['status'])}\n${syncErrorLabel(row['error_code'])}',
                            ),
                            trailing: row['status'] == 'CONFLICT'
                                ? IconButton(
                                    tooltip: row['is_deleted'] == 1
                                        ? 'Confirmar exclusão remota'
                                        : 'Aceitar versão do servidor',
                                    icon: Icon(
                                      row['is_deleted'] == 1
                                          ? AppIcons.deleteForeverOutlined
                                          : AppIcons.cloudDownloadOutlined,
                                    ),
                                    onPressed: data.busy
                                        ? null
                                        : () async {
                                            if (await confirmAction(
                                                  context,
                                                  row['is_deleted'] == 1
                                                      ? 'Confirmar exclusão remota?'
                                                      : 'Aceitar versão remota?',
                                                  row['is_deleted'] == 1
                                                      ? 'A exclusão será reaplicada à revisão mais recente do servidor.'
                                                      : row['entity_type'] ==
                                                            'contacts'
                                                      ? 'Toda a lista local de contatos será reconciliada com o servidor. Edições locais pendentes poderão ser descartadas.'
                                                      : 'Sua edição local desse registro poderá ser substituída. Fotos e notas locais não são enviadas ao servidor.',
                                                ) &&
                                                context.mounted) {
                                              await uiAction(
                                                context,
                                                () => app.operation(
                                                  () =>
                                                      SyncEngine(
                                                        app.repository,
                                                        FirebaseFirestore
                                                            .instance,
                                                      ).resolveConflict(
                                                        row['entity_type']
                                                            as String,
                                                        row['entity_id']
                                                            as String,
                                                        deleted:
                                                            row['is_deleted'] ==
                                                            1,
                                                      ),
                                                ),
                                              );
                                            }
                                          },
                                  )
                                : row['status'] == 'DENIED'
                                ? IconButton(
                                    tooltip: 'Tentar após corrigir acesso',
                                    icon: const Icon(AppIcons.refresh),
                                    onPressed: data.busy
                                        ? null
                                        : () => uiAction(
                                            context,
                                            () => app.operation(() async {
                                              await app.repository.store.db.update(
                                                'outbox',
                                                {
                                                  'status': 'PENDING',
                                                  'next_attempt_at': 0,
                                                },
                                                where:
                                                    'user_id=? AND entity_type=? AND entity_id=?',
                                                whereArgs: [
                                                  app.repository.uid,
                                                  row['entity_type'],
                                                  row['entity_id'],
                                                ],
                                              );
                                            }),
                                          ),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
