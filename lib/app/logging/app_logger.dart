import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final log = Logger(
  level: kReleaseMode ? Level.off : Level.debug,
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: !kReleaseMode,
    printEmojis: !kReleaseMode,
  ),
);
