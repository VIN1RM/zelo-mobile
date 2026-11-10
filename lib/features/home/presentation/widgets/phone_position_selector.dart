import 'package:flutter/material.dart';
import '../../../../shared/presentation/app_icons.dart';
import '../../../monitoring/domain/monitoring_session.dart';

class PhonePositionSelector extends StatelessWidget {
  const PhonePositionSelector({
    required this.position,
    required this.onChanged,
    super.key,
  });
  final PhonePosition position;
  final ValueChanged<PhonePosition>? onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      for (final option in PhonePosition.values)
        ChoiceChip(
          showCheckmark: false,
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          side: BorderSide(
            color: position == option
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          avatar: Icon(
            option == PhonePosition.pocket
                ? AppIcons.phoneAndroidRounded
                : AppIcons.twoWheelerRounded,
            size: 20,
          ),
          label: Text(option.label),
          selected: position == option,
          onSelected: onChanged == null ? null : (_) => onChanged!(option),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
    ],
  );
}
