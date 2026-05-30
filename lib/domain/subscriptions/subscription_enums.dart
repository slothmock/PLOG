enum SubscriptionInterval {
  weekly('weekly'),
  monthly('monthly'),
  quarterly('quarterly'),
  yearly('yearly');

  const SubscriptionInterval(this.dbValue);
  final String dbValue;

  static SubscriptionInterval fromDb(String? v) {
    switch (v) {
      case 'weekly':
        return SubscriptionInterval.weekly;
      case 'quarterly':
        return SubscriptionInterval.quarterly;
      case 'yearly':
        return SubscriptionInterval.yearly;
      case 'monthly':
      default:
        return SubscriptionInterval.monthly;
    }
  }

  String get label {
    switch (this) {
      case SubscriptionInterval.weekly:
        return 'Weekly';
      case SubscriptionInterval.monthly:
        return 'Monthly';
      case SubscriptionInterval.quarterly:
        return 'Quarterly';
      case SubscriptionInterval.yearly:
        return 'Yearly';
    }
  }
}
