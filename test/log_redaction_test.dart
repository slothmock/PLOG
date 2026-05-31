import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logs do not include raw finance or personal fields', () {
    final libDir = Directory('lib');
    final offenders = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();

      final rawErrorMatches = RegExp(r'error:\s*e,').allMatches(source);
      for (final match in rawErrorMatches) {
        offenders.add('${entity.path}: raw exception logged at ${match.start}');
      }

      final logCalls = RegExp(
        r'log\.[idwe]\((?:.|\n)*?\);',
        multiLine: true,
      ).allMatches(source);
      for (final match in logCalls) {
        final call = match.group(0)!;
        final sensitiveTerms = [
          'name=',
          'amount=',
          'openingBalance=',
          'merchant',
          'notes',
          'symbol=',
          'assets=',
          'liabilities=',
          'netWorth=',
          'CategoryState.add("',
          'CategoryState.rename("',
          'deleteWithRules("',
        ];

        for (final term in sensitiveTerms) {
          if (call.contains(term)) {
            offenders.add('${entity.path}: log contains "$term"');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
