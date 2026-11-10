import 'package:flutter/material.dart';

class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });
  final List<int> selected;
  final ValueChanged<List<int>>? onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final minimum = 52 * scale.clamp(1, 2);
      final columns = constraints.maxWidth >= 7 * minimum + 48
          ? 7
          : constraints.maxWidth >= 4 * minimum + 24
          ? 4
          : 3;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 10,
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
            SizedBox(
              width: width,
              child: FilterChip(
                showCheckmark: false,
                label: Center(child: Text(entry.value)),
                labelPadding: EdgeInsets.zero,
                selected: selected.contains(entry.key),
                onSelected: onChanged == null
                    ? null
                    : (value) => onChanged!(
                        value
                            ? ([...selected, entry.key]..sort())
                            : selected
                                  .where((day) => day != entry.key)
                                  .toList(),
                      ),
              ),
            ),
        ],
      );
    },
  );
}
