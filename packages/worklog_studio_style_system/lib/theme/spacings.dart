class Spacings {
  final double none = 0;
  final double xs = 2;
  final double xxs = 4;
  final double sm = 8;
  final double md = 12;
  final double lg = 16;
  final double xl = 24;
  final double x2l = 32;
  final double x3l = 40;
  final double x4l = 48;
  final double x5l = 64;
  final double x6l = 80;

  static const Spacings _instance = Spacings._();
  factory Spacings() => _instance;
  const Spacings._();
}
