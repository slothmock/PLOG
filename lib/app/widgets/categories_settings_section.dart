import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';

import 'package:sloth_ledger/app/state/category_state.dart';
import 'package:sloth_ledger/app/widgets/error_toast.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';

class CategoriesSettingsSection extends ConsumerStatefulWidget {
  const CategoriesSettingsSection({super.key});

  @override
  ConsumerState<CategoriesSettingsSection> createState() =>
      _CategoriesSettingsSectionState();
}

class _CategoriesSettingsSectionState
    extends ConsumerState<CategoriesSettingsSection> {
  List<String>? _items;
  ProviderSubscription<CategoryState>? _categoriesSub;

  @override
  void initState() {
    super.initState();

    _categoriesSub = ref.listenManual<CategoryState>(categoryStateProvider, (
      previous,
      next,
    ) {
      final cats = next.categories;

      if (_items == null || _items!.length != cats.length) {
        if (mounted) {
          setState(() {
            _items = List<String>.of(cats);
          });
        } else {
          _items = List<String>.of(cats);
        }
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _categoriesSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoryStateProvider);
    final categories = _items ?? const <String>[];

    const String lockedCategory = 'Subscriptions';

    bool isLocked(String c) =>
        c.trim().toLowerCase() == lockedCategory.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Categories'),
        if (state.loading && categories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No categories yet.'),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _items!.removeAt(oldIndex);
                _items!.insert(newIndex, item);
              });

              Future.microtask(() async {
                if (!mounted) return;

                await ref.read(categoryStateProvider).reorder(_items!);

                if (!mounted) return;

                final err = ref.read(categoryStateProvider).errorMessage;
                if (err != null) {
                  if (!context.mounted) return;
                  ErrorToast.show(context, message: err);
                  ref.read(categoryStateProvider).clearError();
                }
              });
            },
            itemBuilder: (context, i) {
              final c = categories[i];
              final locked = isLocked(c);

              return ListTile(
                key: ValueKey(c),
                leading: Icon(locked ? Icons.lock : Icons.label),
                title: Text(c),
                onTap: locked ? null : () => _renameDialog(context, from: c),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!locked)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final msg = await ref
                              .read(categoryStateProvider)
                              .deleteWithRules(c);

                          if (!mounted) return;

                          if (msg != null) {
                            if (!context.mounted) return;
                            CustomInfoToast.show(context, message: msg);
                          }

                          final err = ref
                              .read(categoryStateProvider)
                              .errorMessage;
                          if (err != null) {
                            if (!context.mounted) return;
                            ErrorToast.show(context, message: err);
                            ref.read(categoryStateProvider).clearError();
                          }

                          setState(() {
                            _items = List<String>.of(
                              ref.read(categoryStateProvider).categories,
                            );
                          });
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 10.5),
                        child: Tooltip(
                          message: 'Required category',
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                  ],
                ),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add category'),
              onPressed: () => _addDialog(context),
            ),
          ),
        ),
      ],
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

  Future<void> _addDialog(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await ref
                  .read(categoryStateProvider)
                  .add(controller.text);

              setState(() {
                _items = List<String>.of(
                  ref.read(categoryStateProvider).categories,
                );
              });

              if (d.mounted) Navigator.pop(d);

              if (!ok && context.mounted) {
                final err = ref.read(categoryStateProvider).errorMessage;
                if (err != null) {
                  ErrorToast.show(context, message: err);
                  ref.read(categoryStateProvider).clearError();
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(
    BuildContext context, {
    required String from,
  }) async {
    final controller = TextEditingController(text: from);

    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Rename category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await ref
                  .read(categoryStateProvider)
                  .rename(from, controller.text);

              setState(() {
                _items = List<String>.of(
                  ref.read(categoryStateProvider).categories,
                );
              });

              if (d.mounted) Navigator.pop(d);

              if (!ok && context.mounted) {
                final err = ref.read(categoryStateProvider).errorMessage;
                if (err != null) {
                  ErrorToast.show(context, message: err);
                  ref.read(categoryStateProvider).clearError();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
