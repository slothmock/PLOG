class CurrencyFormatter {
  static String compact(
    double value, {
    required String symbol,
    bool showSymbol = true,
  }) {
    final formattedVal = _compactValue(value);
    final formattedSymbol = _formatSymbol(symbol);
    return showSymbol ? '$formattedSymbol$formattedVal' : formattedVal;
  }

  static String _compactValue(double value) {
    final absValue = value.abs();

    if (absValue >= 1e9) {
      return '${_trim(value / 1e9)}B';
    } else if (absValue >= 1e6) {
      return '${_trim(value / 1e6)}M';
    } else if (absValue >= 1e3) {
      return '${_trim(value / 1e3)}k';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  static String _trim(double value) {
    final str = value.toStringAsFixed(1);
    return str.endsWith('.0') ? str.substring(0, str.length - 2) : str;
  }

  static String _formatSymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '${currency.toUpperCase()} ';
    }
  }
}
