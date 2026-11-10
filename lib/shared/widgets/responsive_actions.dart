import 'package:flutter/material.dart';

class ResponsiveActions extends StatelessWidget {
  const ResponsiveActions({
    required this.children,
    this.minimumWidth = 144,
    this.availableWidth,
    super.key,
  });
  final List<Widget> children;
  final double minimumWidth;
  final double? availableWidth;

  @override
  Widget build(BuildContext context) {
    Widget actions(double width) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final horizontal =
          width >=
          children.length * minimumWidth * scale.clamp(1, 1.6) +
              (children.length - 1) * 12;
      return horizontal
          ? Row(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: children[index]),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  children[index],
                ],
              ],
            );
    }

    if (availableWidth != null) return actions(availableWidth!);
    return LayoutBuilder(
      builder: (context, constraints) => actions(constraints.maxWidth),
    );
  }
}
