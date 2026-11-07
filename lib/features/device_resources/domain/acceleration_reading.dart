class AccelerationReading {
  const AccelerationReading({
    required this.x,
    required this.y,
    required this.z,
  });
  final double x;
  final double y;
  final double z;

  factory AccelerationReading.fromNative(Object? value) {
    if (value is! Map) throw const FormatException('Leitura indisponível.');
    double axis(String name) {
      final number = value[name];
      if (number is! num || !number.toDouble().isFinite) {
        throw const FormatException('Leitura indisponível.');
      }
      return number.toDouble();
    }

    return AccelerationReading(x: axis('x'), y: axis('y'), z: axis('z'));
  }
}
