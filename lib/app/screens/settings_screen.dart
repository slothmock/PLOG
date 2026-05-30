import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/widgets/error_toast.dart';
import 'package:sloth_ledger/app/strings/app_strings.dart';
import 'package:sloth_ledger/app/utils/consts.dart';
import 'package:sloth_ledger/app/widgets/categories_settings_section.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            const CategoriesSettingsSection(),
            _sectionHeader(AppStrings.dataTitle),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text(AppStrings.deleteHistoryTitle),
              subtitle: const Text(AppStrings.deleteHistorySubtitle),
              onTap: () => _confirmDeleteTransactions(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.red),
              title: const Text(AppStrings.resetAppTitle),
              subtitle: const Text(AppStrings.resetAppSubtitle),
              onTap: () => _confirmResetApp(context, ref),
            ),
            _sectionHeader(AppStrings.aboutTitle),
            FutureBuilder<String>(
              future: versionString(),
              builder: (context, snap) {
                final v = snap.data ?? '…';
                return ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text(AppStrings.versionTitle),
                  subtitle: Text(v),
                );
              },
            ),
            if (settingsState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  settingsState.errorMessage!,
                  style: TextStyle(color: Colors.red[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTransactions(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.deleteTransactionsQuestion),
        content: const Text(AppStrings.deleteTransactionsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(AppStrings.delete),
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (!context.mounted) return;
              await ref.read(transactionStateProvider).deleteAll();

              if (!context.mounted) return;
              await ref.read(transactionStateProvider).loadAll(force: true);

              if (!context.mounted) return;
              CustomInfoToast.show(context, message: AppStrings.historyDeleted);
            },
          ),
        ],
      ),
    );
  }

  void _confirmResetApp(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final resetState = ref.watch(appResetStateProvider);

            return AlertDialog(
              title: const Text(AppStrings.resetAppQuestion),
              content: const Text(AppStrings.resetAppBody),
              actions: [
                TextButton(
                  onPressed: resetState.loading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(AppStrings.cancel),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: resetState.loading
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);

                          final ok = await ref
                              .read(appResetStateProvider)
                              .reset();

                          if (!context.mounted) return;

                          if (ok) {
                            CustomInfoToast.show(
                              context,
                              message: AppStrings.resetComplete,
                            );
                            ref.invalidate(startupProvider);
                          } else {
                            final err =
                                ref.read(appResetStateProvider).errorMessage ??
                                AppStrings.resetFail;
                            ErrorToast.show(context, message: err);
                            ref.read(appResetStateProvider).clearError();
                          }
                        },
                  child: resetState.loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(AppStrings.reset),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
