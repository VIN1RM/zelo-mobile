import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../shared/widgets/app_view.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) => Scaffold(
      appBar: AppBar(title: const Text('Sincronização')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('${data.pendingSync} operações aguardando confirmação.'),
          Text(data.notice ?? 'Sem confirmação recente do servidor.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: data.busy
                ? null
                : () => uiAction(context, () async {
                    await app.sync();
                  }),
            icon: const Icon(Icons.sync),
            label: const Text('Sincronizar agora'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Conflitos não são sobrescritos automaticamente. Para contatos, aceitar o servidor reconcilia toda a lista. Outras edições locais podem ser substituídas individualmente. Fotos e observações permanecem locais.',
          ),
          FutureBuilder(
            future: app.repository.store.db.rawQuery(
              'SELECT o.*,r.is_deleted FROM outbox o JOIN records r ON o.user_id=r.user_id AND o.entity_type=r.entity_type AND o.entity_id=r.id WHERE o.user_id=?',
              [app.repository.uid],
            ),
            builder: (context, snapshot) => Column(
              children: [
                for (final row in snapshot.data ?? [])
                  Card(
                    child: ListTile(
                      title: Text('${row['entity_type']} • ${row['status']}'),
                      subtitle: Text(
                        'Tentativas: ${row['attempts']} • ${row['error_code'] ?? 'Aguardando rede'}',
                      ),
                      trailing: row['status'] == 'CONFLICT'
                          ? IconButton(
                              tooltip: row['is_deleted'] == 1
                                  ? 'Confirmar exclusão remota'
                                  : 'Aceitar versão do servidor',
                              icon: Icon(
                                row['is_deleted'] == 1
                                    ? Icons.delete_forever_outlined
                                    : Icons.cloud_download_outlined,
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
                                                  FirebaseFirestore.instance,
                                                ).resolveConflict(
                                                  row['entity_type'] as String,
                                                  row['entity_id'] as String,
                                                  deleted:
                                                      row['is_deleted'] == 1,
                                                ),
                                          ),
                                        );
                                      }
                                    },
                            )
                          : row['status'] == 'DENIED'
                          ? IconButton(
                              tooltip: 'Tentar após corrigir acesso',
                              icon: const Icon(Icons.refresh),
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
