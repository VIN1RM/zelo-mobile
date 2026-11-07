import '../../../../shared/presentation/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../monitoring/domain/monitoring_session.dart';

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
                    title: outcomeLabel(session.status),
                    subtitle: session.local
                        ? session.position.label
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    'Seu caminho registrado',
                    subtitle: 'Consulte trajetos, alertas e pedidos de ajuda.',
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const {
                        'all': 'Todos',
                        'sessions': 'Trajetos',
                        'incidents': 'Ocorrências',
                      }.entries)
                        ChoiceChip(
                          label: Text(option.value),
                          selected: filter == option.key,
                          onSelected: (_) =>
                              setState(() => filter = option.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [
                        AppEmptyState(
                          icon: AppIcons.historyRounded,
                          title: 'Nenhum registro neste filtro.',
                          message:
                              'Seus trajetos e ocorrências aparecerão aqui. Você poderá consultar os detalhes sempre que precisar.',
                        ),
                      ],
                    )
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
                            leading: IconBadge(
                              entry.type == 'sessions'
                                  ? AppIcons.twoWheeler
                                  : AppIcons.warningAmber,
                            ),
                            title: Text(entry.title),
                            subtitle: Text(
                              '${dateLabel(entry.at)}\n${entry.subtitle}',
                            ),
                            trailing: const Icon(AppIcons.chevronRight),
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
