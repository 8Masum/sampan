import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/app.dart';
import 'package:sampan/data/database/local_database.dart';
import 'package:sampan/state/sampan_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    developer.log(
      'FlutterError caught in Sampan',
      error: details.exception,
      stackTrace: details.stack,
      name: 'sampan.main',
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    developer.log(
      'Uncaught platform error in Sampan',
      error: error,
      stackTrace: stack,
      name: 'sampan.main',
    );
    return true;
  };

  final String fallbackStoragePath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}sampan_local_store.json';

  runApp(
    ProviderScope(
      overrides: <Override>[
        localDatabaseProvider.overrideWithValue(
          LocalDatabase(
            storageFilePath: fallbackStoragePath,
            resolvePersistentPath: true,
          ),
        ),
      ],
      child: const SampanApp(),
    ),
  );
}
