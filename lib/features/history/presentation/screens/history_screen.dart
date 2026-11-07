import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_view.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) => AppView(
    builder: (context, data, app) {
      final entries =
          <
              ({
                String id,
                String type,
                String title,
                String subtitle,
                DateTime at,
              })
            >[
              if (filter != 'incidents')
                for (final session in data.sessions)
                  (
                    id: session.id,
                    type: 'sessions',
                    title: 'Trajeto • ${outcomeLabel(session.status)}',
                    subtitle: session.local
                        ? session.position.name
                        : 'Sessão de outro aparelho',
                    at: session.startedAt,
                  ),
              if (filter != 'sessions')
                for (final incident in data.incidents)
                  (
                    id: incident.id,
                    type: 'incidents',
                    title: incident.label,
                    subtitle:
                        '${outcomeLabel(incident.outcome)} • ${outcomeLabel(incident.condition)}${incident.preserved ? ' • Preservado' : ''}',
                    at: incident.occurredAt,
                  ),
            ]
            ..sort((a, b) => b.at.compareTo(a.at));
      return Scaffold(
        appBar: AppBar(title: const Text('Histórico')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Todos')),
                  ButtonSegment(value: 'sessions', label: Text('Trajetos')),
                  ButtonSegment(value: 'incidents', label: Text('Ocorrências')),
                ],
                selected: {filter},
                onSelectionChanged: (value) =>
                    setState(() => filter = value.single),
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('Nenhum registro neste filtro.'))
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: Icon(
                              entry.type == 'sessions'
                                  ? Icons.two_wheeler
                                  : Icons.warning_amber,
                            ),
                            title: Text(entry.title),
                            subtitle: Text(
                              '${dateLabel(entry.at)}\n${entry.subtitle}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '/historico/${entry.type}/${entry.id}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}
