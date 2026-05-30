import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';

import 'package:sloth_ledger/app/strings/app_strings.dart';
import 'package:sloth_ledger/app/widgets/error_toast.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';

import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/domain/accounts/account_enums.dart';

class AddAccountModal extends ConsumerStatefulWidget {
  const AddAccountModal({super.key, this.account});

  final SlothAccount? account;

  @override
  ConsumerState<AddAccountModal> createState() => _AddAccountModalState();
}

class _AddAccountModalState extends ConsumerState<AddAccountModal> {
  final _name = TextEditingController();
  final _opening = TextEditingController();

  AccountCategory _category = AccountCategory.asset;
  AccountType? _type;

  @override
  void initState() {
    super.initState();

    final a = widget.account;

    _name.text = a?.name ?? '';
    _opening.text = (a?.openingBalance ?? 0.0).toStringAsFixed(2);

    _category = a?.category ?? AccountCategory.asset;

    final allowed = accountTypesFor(_category);

    if (a != null && allowed.contains(a.type)) {
      _type = a.type;
    } else {
      _type = allowed.first;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ErrorToast.show(context, message: 'Enter a name');
      return;
    }

    final rawOpening = _opening.text.trim().replaceAll(',', '');
    final opening = double.tryParse(rawOpening);
    if (opening == null) {
      ErrorToast.show(
        context,
        message: 'Please enter a valid number for opening balance.',
      );
      return;
    }

    final type = _type;
    if (type == null) {
      ErrorToast.show(context, message: 'Choose an account type');
      return;
    }

    final state = ref.watch(accountStateProvider);
    final isEdit = widget.account?.id != null;

    Navigator.pop(context);

    if (isEdit) {
      await state.update(
        id: widget.account!.id!,
        name: name,
        category: _category,
        type: type,
        currency: 'GBP',
        openingBalance: opening,
      );
    } else {
      await state.create(
        name: name,
        category: _category,
        type: type,
        currency: 'GBP',
        openingBalance: opening,
      );
    }

    if (!mounted) return;

    final err = state.errorMessage;
    if (err != null) {
      ErrorToast.show(context, message: err);
      state.clearError();
      return;
    }

    CustomInfoToast.show(
      context,
      message: isEdit ? 'Account updated' : 'Account added',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;
    final title = isEdit ? AppStrings.editAccount : AppStrings.addAccount;

    final allowedTypes = accountTypesFor(_category);
    if (_type == null || !allowedTypes.contains(_type)) {
      _type = allowedTypes.first;
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: AppStrings.accountName,
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _opening,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: AppStrings.startingBalance,
                      border: OutlineInputBorder(),
                      hintText: '0.00',
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<AccountCategory>(
                    initialValue: _category,
                    items: AccountCategory.values
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.label)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _category = v;
                        _type = accountTypesFor(_category).first;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<AccountType>(
                    initialValue: _type,
                    items: allowedTypes
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.label)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _type = v),
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: Text(isEdit ? 'Save changes' : 'Add account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
