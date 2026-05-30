import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/widgets/error_toast.dart';

import 'package:sloth_ledger/domain/accounts/account.dart';
import 'package:sloth_ledger/features/ledger/state/account_state.dart';

class TransferModal extends ConsumerStatefulWidget {
  const TransferModal({super.key, this.fromAccountId});

  final int? fromAccountId; // optional preselect

  @override
  ConsumerState<TransferModal> createState() => _TransferModalState();
}

class _TransferModalState extends ConsumerState<TransferModal> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _date = DateTime.now();

  int? _fromId;
  int? _toId;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fromId = widget.fromAccountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;

    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      useRootNavigator: true,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked == null) return;

    setState(() {
      _date = DateTime(
        _date.year,
        _date.month,
        _date.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  SlothAccount? _acc(AccountState s, int? id) => id == null ? null : s.byId(id);

  List<SlothAccount> _eligibleToAccounts(AccountState s, SlothAccount from) {
    // Same category + same currency, not the same account.
    return s.accounts
        .where(
          (a) =>
              a.id != null &&
              a.id != from.id &&
              a.category == from.category &&
              a.currency == from.currency,
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final raw = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    if (raw == null || raw <= 0) {
      ErrorToast.show(context, message: 'Enter a valid amount');
      return;
    }

    final state = ref.watch(accountStateProvider);
    final from = _acc(state, _fromId);
    final to = _acc(state, _toId);

    if (from == null || to == null) {
      ErrorToast.show(context, message: 'Select valid From and To accounts');
      return;
    }

    if (from.id == to.id) {
      ErrorToast.show(context, message: 'Choose two different accounts');
      return;
    }

    // Enforce same category + currency (your definition)
    if (from.category != to.category || from.currency != to.currency) {
      ErrorToast.show(
        context,
        message: 'Transfers must be within the same category and currency',
      );
      return;
    }

    setState(() => _submitting = true);

    // Close keyboard
    FocusScope.of(context).unfocus();

    final txnState = ref.read(transactionStateProvider);
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    final ok = await txnState.transfer(
      fromAccountId: from.id!,
      toAccountId: to.id!,
      amount: raw,
      notes: notes,
      dateMillis: _date.millisecondsSinceEpoch,
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (!ok) {
      ErrorToast.show(
        context,
        message: txnState.errorMessage ?? 'Transfer failed',
      );
      txnState.clearError();
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountStateProvider);
    final accounts = accountState.accounts;

    // If nothing preselected, pick first account (if any)
    if (_fromId == null && accounts.isNotEmpty) {
      _fromId = accounts.first.id;
    }

    final from = _acc(accountState, _fromId);

    final toCandidates = (from == null)
        ? <SlothAccount>[]
        : _eligibleToAccounts(accountState, from);

    // If "to" is invalid for the chosen from, snap it.
    if (from != null) {
      final stillValid = toCandidates.any((a) => a.id == _toId);
      if (!stillValid) {
        _toId = toCandidates.isEmpty ? null : toCandidates.first.id;
      }
    } else {
      _toId = null;
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
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Transfer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    initialValue: _fromId,
                    items: accounts
                        .where((a) => a.id != null)
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              '${a.name} • ${a.categoryLabel} • ${a.currency}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() {
                            _fromId = v;
                          }),
                    decoration: const InputDecoration(
                      labelText: 'From',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    initialValue: _toId,
                    items: toCandidates
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (_submitting || toCandidates.isEmpty)
                        ? null
                        : (v) => setState(() => _toId = v),
                    decoration: InputDecoration(
                      labelText: 'To',
                      border: const OutlineInputBorder(),
                      helperText: (from == null)
                          ? 'Select a From account first'
                          : (toCandidates.isEmpty)
                          ? 'No eligible accounts (same category + currency)'
                          : 'Same category + currency only',
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount (${from?.currency ?? '—'})',
                      border: const OutlineInputBorder(),
                    ),
                    enabled: !_submitting,
                  ),

                  const SizedBox(height: 8),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(DateFormat.yMMMd().add_jm().format(_date)),
                    onTap: _submitting
                        ? null
                        : () async {
                            await _pickDate();
                            await _pickTime();
                          },
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_submitting,
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.swap_horiz),
                      label: Text(_submitting ? 'Transferring…' : 'Transfer'),
                      onPressed: _submitting ? null : _submit,
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
