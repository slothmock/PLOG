import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';

import 'package:sloth_ledger/app/widgets/error_toast.dart';
import 'package:sloth_ledger/app/widgets/info_toast.dart';
import 'package:sloth_ledger/domain/subscriptions/subscription.dart';

class AddSubscriptionModal extends ConsumerStatefulWidget {
  const AddSubscriptionModal({super.key, this.subscription});

  final SlothSubscription? subscription;

  @override
  ConsumerState<AddSubscriptionModal> createState() =>
      _AddSubscriptionModalState();
}

class _AddSubscriptionModalState extends ConsumerState<AddSubscriptionModal> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  DateTime _nextDue = DateTime.now();
  String _interval = 'monthly';
  int? _accountId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final s = widget.subscription;
    if (s != null) {
      _name.text = s.name;
      _amount.text = s.amount.toStringAsFixed(2);
      _nextDue = s.nextDue;
      _interval = s.interval.name;
      _accountId = s.accountId;
      _isActive = s.isActive;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickNextDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDue,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      _nextDue = DateTime(picked.year, picked.month, picked.day, 9, 0);
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final rawAmount = double.tryParse(_amount.text.trim());

    if (name.isEmpty) {
      ErrorToast.show(context, message: 'Enter a name');
      return;
    }
    if (rawAmount == null || rawAmount <= 0) {
      ErrorToast.show(context, message: 'Enter a valid amount');
      return;
    }

    if (_accountId == null) {
      ErrorToast.show(context, message: 'Choose an account');
      return;
    }

    final currencyCode = ref.read(settingsStateProvider).settings.currencyCode;

    final state = ref.read(subscriptionStateProvider);
    final isEdit = widget.subscription?.id != null;

    Navigator.pop(context);

    bool ok;
    if (isEdit) {
      ok = await state.update(
        id: widget.subscription!.id!,
        name: name,
        amount: rawAmount,
        interval: _interval,
        nextDue: _nextDue,
        accountId: _accountId!,
        isActive: _isActive,
      );
    } else {
      ok = await state.create(
        name: name,
        amount: rawAmount,
        currency: currencyCode,
        interval: _interval,
        nextDue: _nextDue,
        accountId: _accountId!,
      );
    }

    if (!mounted) return;

    if (!ok) {
      final msg = state.errorMessage ?? 'Operation failed';
      ErrorToast.show(context, message: msg);
      state.clearError();
    } else {
      CustomInfoToast.show(
        context,
        message: isEdit ? 'Subscription updated' : 'Subscription added',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountStateProvider).accounts;
    final isEdit = widget.subscription != null;

    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }

    final title = isEdit ? 'Edit Subscription' : 'Add Subscription';

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
                      labelText: 'Name',
                      hintText: 'Netflix, Spotify, iCloud...',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _interval,
                    items: const [
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: 'quarterly',
                        child: Text('Quarterly'),
                      ),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (v) =>
                        setState(() => _interval = v ?? 'monthly'),
                    decoration: const InputDecoration(
                      labelText: 'Interval',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Next due'),
                    subtitle: Text(DateFormat.yMMMd().format(_nextDue)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickNextDue,
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<int>(
                    initialValue: _accountId,
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _accountId = v),
                    decoration: const InputDecoration(
                      labelText: 'Paid from account',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: Text(isEdit ? 'Save changes' : 'Add subscription'),
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
