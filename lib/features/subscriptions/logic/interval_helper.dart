import 'package:sloth_ledger/domain/subscriptions/subscription_enums.dart';

DateTime addInterval(
  DateTime d,
  SubscriptionInterval interval, {
  int count = 1,
}) {
  switch (interval) {
    case SubscriptionInterval.weekly:
      return d.add(Duration(days: 7 * count));

    case SubscriptionInterval.monthly:
      {
        final y = d.year;
        final m = d.month + count;
        final day = d.day;

        // Dart auto-rolls months, but day overflow can jump months weirdly.
        // Clamp day to last day of target month.
        final firstOfTarget = DateTime(
          y,
          m,
          1,
          d.hour,
          d.minute,
          d.second,
          d.millisecond,
          d.microsecond,
        );
        final firstOfNext = DateTime(
          firstOfTarget.year,
          firstOfTarget.month + 1,
          1,
        );
        final lastDay = firstOfNext.subtract(const Duration(days: 1)).day;
        final safeDay = day > lastDay ? lastDay : day;

        return DateTime(
          firstOfTarget.year,
          firstOfTarget.month,
          safeDay,
          d.hour,
          d.minute,
          d.second,
          d.millisecond,
          d.microsecond,
        );
      }

    case SubscriptionInterval.quarterly:
      {
        final y = d.year;
        final m = d.month + (3 * count);
        final day = d.day;

        // Dart auto-rolls months, but day overflow can jump months weirdly.
        // Clamp day to last day of target month.
        final firstOfTarget = DateTime(
          y,
          m,
          1,
          d.hour,
          d.minute,
          d.second,
          d.millisecond,
          d.microsecond,
        );
        final firstOfNext = DateTime(
          firstOfTarget.year,
          firstOfTarget.month + 1,
          1,
        );
        final lastDay = firstOfNext.subtract(const Duration(days: 1)).day;
        final safeDay = day > lastDay ? lastDay : day;

        return DateTime(
          firstOfTarget.year,
          firstOfTarget.month,
          safeDay,
          d.hour,
          d.minute,
          d.second,
          d.millisecond,
          d.microsecond,
        );
      }

    case SubscriptionInterval.yearly:
      {
        final target = DateTime(
          d.year + count,
          d.month,
          1,
          d.hour,
          d.minute,
          d.second,
          d.millisecond,
          d.microsecond,
        );
        final firstOfNext = DateTime(target.year, target.month + 1, 1);
        final lastDay = firstOfNext.subtract(const Duration(days: 1)).day;
        final safeDay = d.day > lastDay ? lastDay : d.day;

        return DateTime(
          target.year,
          target.month,
          safeDay,
          d.hour,
          d.minute,
          d.second,
          d.millisecond,
          d.microsecond,
        );
      }
  }
}
