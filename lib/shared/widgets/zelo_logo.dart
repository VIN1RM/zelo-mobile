import 'package:flutter/material.dart';

class ZeloLogo extends StatelessWidget {
  const ZeloLogo({this.size = 80, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/branding/logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
