import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_content.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_components.dart';

typedef LicenseLoader =
    Future<Map<String, List<List<LicenseParagraph>>>> Function();

Future<Map<String, List<List<LicenseParagraph>>>> loadAppLicenses() async {
  final packages = <String, List<List<LicenseParagraph>>>{};
  await for (final entry in LicenseRegistry.licenses) {
    final paragraphs = entry.paragraphs.toList();
    for (final package in entry.packages) {
      packages.putIfAbsent(package, () => []).add(paragraphs);
    }
  }
  return packages;
}

class LicensesScreen extends StatefulWidget {
  const LicensesScreen({this.loader = loadAppLicenses, super.key});
  final LicenseLoader loader;

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  late Future<Map<String, List<List<LicenseParagraph>>>> _licenses;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _licenses = widget.loader();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader(title: Text('Licenças')),
    body: AppContent(
      child: FutureBuilder(
        future: _licenses,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppScrollView(
              children: [
                AppEmptyState(
                  icon: Icons.description_outlined,
                  title: 'Não foi possível abrir as licenças',
                  message:
                      'Tente carregar novamente para consultar os créditos.',
                  action: FilledButton(
                    onPressed: () {
                      final retry = widget.loader();
                      setState(() {
                        _licenses = retry;
                      });
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando licenças',
              ),
            );
          }
          final packages = snapshot.data!;
          final names =
              packages.keys
                  .where((name) => name.toLowerCase().contains(_query))
                  .toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeading(
                        'Feito com boas tecnologias',
                        subtitle:
                            'Conheça os componentes de código aberto usados pelo ZELO e consulte seus textos de licença.',
                      ),
                      TextField(
                        controller: _search,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          labelText: 'Buscar componente',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar busca',
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${names.length} de ${packages.length} componentes',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
              if (names.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(
                    child: AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Nenhum componente encontrado',
                      message: 'Tente outro nome ou limpe a busca.',
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.builder(
                  itemCount: names.length,
                  itemBuilder: (context, index) {
                    final name = names[index];
                    return AppActionTile(
                      icon: Icons.description_outlined,
                      title: name,
                      subtitle: 'Ler licença e créditos',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LicenseDetailsScreen(
                            package: name,
                            licenses: packages[name]!,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class LicenseDetailsScreen extends StatelessWidget {
  const LicenseDetailsScreen({
    required this.package,
    required this.licenses,
    super.key,
  });
  final String package;
  final List<List<LicenseParagraph>> licenses;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader(title: Text('Detalhes da licença')),
    body: SelectionArea(
      child: AppScrollView(
        children: [
          SectionHeading(
            package,
            subtitle: 'Texto original disponibilizado pelo componente.',
          ),
          for (var index = 0; index < licenses.length; index++) ...[
            if (licenses.length > 1) SectionHeading('Licença ${index + 1}'),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final paragraph in licenses[index])
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: 16,
                        left: paragraph.indent > 0 ? 12 : 0,
                      ),
                      child: Text(
                        paragraph.text,
                        textAlign:
                            paragraph.indent == LicenseParagraph.centeredIndent
                            ? TextAlign.center
                            : TextAlign.start,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
  );
}
