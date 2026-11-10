import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/platform/device_permissions.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_view.dart';
import '../../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/reminder_gateway.dart';
import '../../domain/reminder_settings.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  final _guard = GlobalKey<UnsavedChangesGuardState>();
  final _changes = TextEditingController();
  late Future<ReminderSettings> _initial;
  bool _initialized = false;
  bool _enabled = false;
  bool _busy = false;
  List<int> _minutes = [480];
  List<int> _days = [1, 2, 3, 4, 5];
  String? _error;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authUserProvider).asData?.value?.id;
    _initial = _load();
  }

  Future<ReminderSettings> _load() async {
    if (_uid == null) throw StateError('No session');
    return ref.read(reminderGatewayProvider).load(_uid!);
  }

  @override
  void dispose() {
    _changes.dispose();
    super.dispose();
  }

  ReminderSettings get settings =>
      ReminderSettings(enabled: _enabled, minutes: _minutes, weekdays: _days);
  void change(VoidCallback update) {
    setState(() {
      update();
      _error = null;
    });
    _changes.text = settings.toJson().toString();
  }

  Future<void> pickTime([int? index]) async {
    final minute = index == null ? 480 : _minutes[index];
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (selected == null || !mounted) return;
    final value = selected.hour * 60 + selected.minute;
    if (index != null && _minutes[index] == value) return;
    if (_minutes.contains(value)) {
      setState(() => _error = 'Este horário já foi adicionado.');
      return;
    }
    change(() {
      if (index == null) {
        _minutes = [..._minutes, value];
      } else {
        _minutes = [..._minutes]..[index] = value;
      }
      _minutes.sort();
    });
  }

  Future<void> save() async {
    final uid = _uid;
    if (_busy ||
        uid == null ||
        uid != ref.read(authUserProvider).asData?.value?.id) {
      return;
    }
    final invalid = settings.error;
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_enabled && !await DevicePermissions.requestNotifications()) {
        if (mounted) {
          setState(
            () => _error =
                'Permita as notificações nos ajustes do Android para ativar os lembretes.',
          );
        }
        return;
      }
      if (!mounted || uid != ref.read(authUserProvider).asData?.value?.id) {
        return;
      }
      final saved = await uiAction(
        context,
        () => ref.read(reminderGatewayProvider).save(uid, settings),
        success: _enabled
            ? 'Lembretes salvos neste aparelho.'
            : 'Lembretes desativados.',
      );
      if (saved) await _guard.currentState?.acceptChanges();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'N\u00e3o foi poss\u00edvel salvar. Confira as permiss\u00f5es e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _initial,
    builder: (context, snapshot) {
      if (!_initialized && snapshot.hasData) {
        final initial = snapshot.data!;
        _enabled = initial.enabled;
        _minutes = [...initial.minutes];
        _days = [...initial.weekdays];
        _changes.text = settings.toJson().toString();
        _initialized = true;
      }
      if (!_initialized) {
        return Scaffold(
          appBar: const AppHeader(
            title: Text('Lembretes de prote\u00e7\u00e3o'),
          ),
          body: AppScrollView(
            children: [
              if (snapshot.hasError)
                AppEmptyState(
                  icon: Icons.notifications_none,
                  title: 'Não foi possível abrir os lembretes',
                  message: 'Tente novamente no aplicativo Android.',
                  action: FilledButton(
                    onPressed: () => setState(() {
                      _initial = _load();
                    }),
                    child: const Text('Tentar novamente'),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Carregando lembretes',
                  ),
                ),
            ],
          ),
        );
      }
      return UnsavedChangesGuard(
        key: _guard,
        controllers: [_changes],
        child: Scaffold(
          appBar: const AppHeader(title: Text('Lembretes de proteção')),
          body: AppScrollView(
            children: [
              const SectionHeading(
                'Um lembrete antes de sair',
                subtitle:
                    'Escolha até três horários e os dias em que deseja ser lembrado.',
              ),
              SectionCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Receber lembretes'),
                  subtitle: const Text(
                    'Desativado por padrão. Salvo somente neste aparelho.',
                  ),
                  value: _enabled,
                  onChanged: _busy
                      ? null
                      : (value) => change(() => _enabled = value),
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeading('Dias da semana'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    1: 'Seg',
                    2: 'Ter',
                    3: 'Qua',
                    4: 'Qui',
                    5: 'Sex',
                    6: 'Sáb',
                    7: 'Dom',
                  }.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _days.contains(entry.key),
                      onSelected: _busy
                          ? null
                          : (selected) => change(() {
                              _days = selected
                                  ? ([..._days, entry.key]..sort())
                                  : _days
                                        .where((value) => value != entry.key)
                                        .toList();
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeading('Horários'),
              for (var index = 0; index < _minutes.length; index++)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(
                      '${(_minutes[index] ~/ 60).toString().padLeft(2, '0')}:${(_minutes[index] % 60).toString().padLeft(2, '0')}',
                    ),
                    subtitle: const Text('Toque para alterar'),
                    onTap: _busy ? null : () => pickTime(index),
                    trailing: IconButton(
                      tooltip: 'Remover horário',
                      onPressed: _busy
                          ? null
                          : () => change(
                              () => _minutes = [..._minutes]..removeAt(index),
                            ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              if (_minutes.length < 3)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => pickTime(),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar horário'),
                ),
              const SizedBox(height: 20),
              const StatusPanel(
                title: 'Você decide quando começar',
                message:
                    'O lembrete abre o ZELO e não inicia a proteção. O Android pode atrasar os avisos para economizar bateria. Os horários acompanham o fuso do aparelho.',
                icon: Icons.info_outline,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => uiAction(context, DevicePermissions.openSettings),
                  child: const Text('Abrir ajustes do Android'),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : save,
                child: LoadingLabel(loading: _busy, label: 'Salvar lembretes'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
