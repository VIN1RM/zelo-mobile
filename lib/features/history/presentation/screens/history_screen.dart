import '../../domain/history_filter.dart';
import '../../../../shared/widgets/app_header.dart';
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
  String query = '';
  DateTimeRange? period;
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void clearFilters() {
    search.clear();
    setState(() {
      query = '';
      period = null;
      filter = 'all';
    });
  }

  Future<void> selectPeriod() async {
    final now = DateTime.now();
    final chosen = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: period,
      helpText: 'Filtrar por per\u00edodo',
      saveText: 'Aplicar',
    );
    if (chosen != null && mounted) setState(() => period = chosen);
  }

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
              .where(
                (entry) => matchesHistoryFilter(
                  at: entry.at,
                  text:
                      '${entry.title} ${entry.subtitle} ${dateLabel(entry.at)}',
                  query: query,
                  period: period,
                ),
              )
              .toList()
            ..sort((a, b) => b.at.compareTo(a.at));
      return Scaffold(
        appBar: AppHeader(title: const Text('Histórico')),
        body: AppContent(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(
                        'Seu caminho registrado',
                        subtitle:
                            'Consulte trajetos, alertas e pedidos de ajuda.',
                      ),
                      TextField(
                        controller: search,
                        onChanged: (value) => setState(() => query = value),
                        decoration: InputDecoration(
                          labelText: 'Buscar registros',
                          hintText:
                              'Trajeto, alerta, situa\u00e7\u00e3o ou data',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar busca',
                                  onPressed: () {
                                    search.clear();
                                    setState(() => query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: selectPeriod,
                            icon: const Icon(Icons.date_range_rounded),
                            label: Text(
                              period == null
                                  ? 'Selecionar per\u00edodo'
                                  : '${period!.start.day}/${period!.start.month}/${period!.start.year} a ${period!.end.day}/${period!.end.month}/${period!.end.year}',
                            ),
                          ),
                          if (period != null ||
                              query.isNotEmpty ||
                              filter != 'all')
                            TextButton(
                              onPressed: clearFilters,
                              child: const Text('Limpar filtros'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in const {
                            'all': 'Todos',
                            'sessions': 'Trajetos',
                            'incidents': 'Ocorr\u00eancias',
                          }.entries)
                            ChoiceChip(
                              label: Text(option.value),
                              selected: filter == option.key,
                              onSelected: (_) =>
                                  setState(() => filter = option.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${entries.length} registros',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (entries.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(
                    child: AppEmptyState(
                      icon: AppIcons.historyRounded,
                      title: 'Nenhum registro neste filtro.',
                      message:
                          'Seus trajetos e ocorr\u00eancias aparecer\u00e3o aqui. Consulte os detalhes sempre que precisar.',
                      action: filter == 'all' && query.isEmpty && period == null
                          ? null
                          : OutlinedButton(
                              onPressed: clearFilters,
                              child: const Text('Mostrar todos os registros'),
                            ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final isNewDay =
                        index == 0 ||
                        DateUtils.dateOnly(entries[index - 1].at.toLocal()) !=
                            DateUtils.dateOnly(entry.at.toLocal());
                    final date = entry.at.toLocal();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isNewDay)
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: IconBadge(
                              entry.type == 'sessions'
                                  ? AppIcons.twoWheeler
                                  : AppIcons.warningAmber,
                              tone: entry.type == 'sessions'
                                  ? AppTone.neutral
                                  : AppTone.warning,
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
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
