class MoneyMinor {
  static int fromDouble(double value) => (value * 100).round();
  static double toDouble(int value) => value / 100.0;
}
