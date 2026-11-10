class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.minutes = const [480],
    this.weekdays = const [1, 2, 3, 4, 5],
  });
  final bool enabled;
  final List<int> minutes;
  final List<int> weekdays;

  factory ReminderSettings.fromJson(Map<String, dynamic> json) =>
      ReminderSettings(
        enabled: json['enabled'] == true,
        minutes: (json['minutes'] as List? ?? [480]).cast<int>(),
        weekdays: (json['weekdays'] as List? ?? [1, 2, 3, 4, 5]).cast<int>(),
      );
  String? get error =>
      minutes.isEmpty ||
          minutes.length > 3 ||
          minutes.any((value) => value < 0 || value >= 1440) ||
          minutes.toSet().length != minutes.length ||
          weekdays.isEmpty ||
          weekdays.any((value) => value < 1 || value > 7)
      ? 'Escolha de um a três horários diferentes e pelo menos um dia da semana.'
      : null;
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'minutes': minutes,
    'weekdays': weekdays,
  };
}
