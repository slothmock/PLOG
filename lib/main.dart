import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/app.dart';
import 'package:sloth_ledger/app/strings/app_strings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SlothBudgetRoot()));
}

class SlothBudgetRoot extends ConsumerWidget {
  const SlothBudgetRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppStrings.appName,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: startup.when(
        loading: () => const _SplashScreen(),
        error: (error, stack) => _StartupErrorScreen(error: error),
        data: (_) => const SlothBudgetApp(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final Object error;
  const _StartupErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Startup failed: $error')));
  }
}
