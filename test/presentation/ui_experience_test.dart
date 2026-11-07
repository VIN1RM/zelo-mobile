import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zelo_mobile/app/theme/app_theme.dart';
import 'package:zelo_mobile/core/application/app_controller.dart';
import 'package:zelo_mobile/core/data/zelo_repository.dart';
import 'package:zelo_mobile/core/database/local_store.dart';
import 'package:zelo_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:zelo_mobile/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:zelo_mobile/features/contacts/presentation/screens/contact_form_screen.dart';
import 'package:zelo_mobile/features/emergency/domain/incident.dart';
import 'package:zelo_mobile/features/emergency/presentation/screens/emergency_screens.dart';
import 'package:zelo_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:zelo_mobile/features/history/presentation/screens/record_details_screen.dart';
import 'package:zelo_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:zelo_mobile/features/monitoring/domain/monitoring_session.dart';
import 'package:zelo_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:zelo_mobile/features/settings/presentation/screens/sync_screen.dart';
import '../support/fake_auth_repository.dart';

class _PreviewController extends AppController {
  _PreviewController(this.localRepository, this.snapshot);
  final ZeloRepository localRepository;
  final AppSnapshot snapshot;
  @override
  Future<AppSnapshot> build() async {
    repository = localRepository;
    return snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LocalStore store;
  late ZeloRepository repository;
  setUp(() async {
    store = LocalStore(
      await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: LocalStore.createSchema,
        ),
      ),
    );
    repository = ZeloRepository(store, 'ui-preview');
    for (var index = 0; index < 3; index++) {
      await repository.saveContact(
        name: ['Ana · Família', 'Pedro · Amigo', 'Mariana · Trabalho'][index],
        phone: '+551199999000$index',
        email: 'contato$index@example.test',
      );
    }
    final rows = await repository.rows('contacts');
    for (var index = 0; index < rows.length; index++) {
      await store.db.update(
        'outbox',
        {
          'status': ['PENDING', 'DENIED', 'CONFLICT'][index],
          'error_code': [
            null,
            'permission-denied',
            'CONTACT_REVISION_CONFLICT',
          ][index],
        },
        where: 'user_id=? AND entity_id=?',
        whereArgs: [repository.uid, rows[index]['id']],
      );
    }
  });
  tearDown(() => store.close());

  const screens = <String, Widget>{
    'inicio': HomeScreen(),
    'contatos': ContactsScreen(),
    'novo-contato': ContactFormScreen(),
    'historico': HistoryScreen(),
    'sincronizacao': SyncScreen(),
    'ajustes': SettingsScreen(),
    'alerta': AlertScreen(id: 'incident-preview'),
    'ajuda': HelpScreen(id: 'incident-preview'),
    'detalhes': RecordDetailsScreen(type: 'sessions', id: 'session-preview'),
  };

  for (final screen in screens.entries) {
    for (final enlarged in [false, true]) {
      testWidgets(
        '${screen.key}: Portuguese labels and ${enlarged ? 'enlarged text on narrow screen' : 'phone layout'}',
        (tester) async {
          tester.view.physicalSize = enlarged
              ? const Size(320, 700)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final font = FontLoader('Karla')
            ..addFont(rootBundle.load('assets/fonts/karla/Karla-Variable.ttf'));
          await tester.runAsync(font.load);
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await tester.runAsync(icons.load);
          final auth = FakeAuthRepository(user: verifiedUser);
          addTearDown(auth.dispose);
          final snapshot = AppSnapshot(
            prepared: true,
            pendingSync: 3,
            contacts: await tester.runAsync(repository.contacts) ?? [],
            sessions: [
              MonitoringSession(
                id: 'session-preview',
                startedAt: DateTime(2026, 11, 7, 14, 30),
                endedAt: DateTime(2026, 11, 7, 15),
                status: 'COMPLETED',
                position: PhonePosition.pocket,
              ),
            ],
            incidents: [
              Incident(
                id: 'incident-preview',
                type: 'POSSIBLE_ACCIDENT',
                occurredAt: DateTime(2026, 11, 7, 14, 45),
                outcome: screen.key == 'alerta' ? 'PENDING' : 'TIMED_OUT',
                condition: 'SAFE',
                preserved: true,
              ),
            ],
            alertRemainingSeconds: 25,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appControllerProvider.overrideWith(
                  () => _PreviewController(repository, snapshot),
                ),
                authRepositoryProvider.overrideWithValue(auth),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                locale: const Locale('pt', 'BR'),
                supportedLocales: const [Locale('pt', 'BR')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(enlarged ? 2 : 1)),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: const ValueKey('preview'),
                  child: screen.value,
                ),
              ),
            ),
          );
          for (var frame = 0; frame < 5; frame++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 80)),
            );
            await tester.pump();
          }
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/images/branding/logo.png'),
              tester.element(find.byType(MaterialApp)),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (screen.key == 'sincronizacao') {
            await tester.scrollUntilVisible(
              find.textContaining('Acesso não autorizado'),
              200,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 30,
            );
            expect(find.textContaining('Acesso não autorizado'), findsWidgets);
            if (!enlarged) {
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, 1500),
              );
              await tester.pumpAndSettle();
            }
          }
          if (screen.key == 'historico') {
            await tester.scrollUntilVisible(
              find.textContaining('Bolso'),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.textContaining('Bolso'), findsWidgets);
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, 1000),
            );
            await tester.pumpAndSettle();
          }
          if (!enlarged && const bool.fromEnvironment('ZELO_UI_PREVIEW')) {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('preview')),
              );
              final rendered = await boundary.toImage(pixelRatio: 2);
              final bytes = await rendered.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/ui-preview').create(recursive: true);
              await File(
                'build/ui-preview/${screen.key}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              rendered.dispose();
            });
          }
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            for (var index = 0; index < 5; index++) {
              await tester.drag(scrollables.first, const Offset(0, -450));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
          if (screen.key == 'novo-contato') {
            await tester.ensureVisible(find.text('Salvar contato'));
            await tester.tap(find.text('Salvar contato'));
            await tester.pumpAndSettle();
            expect(
              find.text('O nome deve ter de 2 a 80 caracteres.'),
              findsOneWidget,
            );
            expect(
              find.text('Informe um WhatsApp ou preencha o e-mail abaixo.'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
          final texts = tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data ?? '')
              .join('\n');
          expect(
            RegExp(
              r'\b(pocket|mount|DENIED|PENDING|CONFLICT|OPENED|COPIED|FAILED|permission-denied)\b',
            ).hasMatch(texts),
            isFalse,
          );
        },
      );
    }
  }
}
