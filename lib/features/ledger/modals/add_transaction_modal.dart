import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/app/widgets/error_toast.dart';

import 'package:sloth_ledger/domain/transactions/transaction.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  final SlothTransaction? transaction;

  const AddTransactionModal({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionModal> createState() =>
      _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();

  DateTime _date = DateTime.now();
  bool _isExpense = true;
  String? _selectedCategory;
  int? _selectedAccountId;

  @override
  void initState() {
    super.initState();

    final txn = widget.transaction;
    if (txn != null) {
      _amountController.text = txn.amount.abs().toStringAsFixed(2);
      _isExpense = txn.isExpense;
      _date = txn.date;
      _selectedCategory = txn.category;
      _selectedAccountId = txn.accountId;
      _notesController.text = txn.notes ?? '';
      _merchantController.text = txn.merchant ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _merchantController.dispose();
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

  Future<void> _saveTransaction({required bool addMore}) async {
    final raw = double.tryParse(_amountController.text.trim());
    if (raw == null || raw <= 0) {
      ErrorToast.show(context, message: 'Enter a valid amount');
      return;
    }

    if (_selectedCategory == null || _selectedAccountId == null) {
      ErrorToast.show(context, message: 'Select category and account');
      return;
    }

    final amount = _isExpense ? -raw : raw;
    final state = ref.read(transactionStateProvider);
    final isEdit = widget.transaction != null;

    final merchant = _merchantController.text.trim().isEmpty
        ? null
        : _merchantController.text.trim();

    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    bool ok;
    if (isEdit) {
      ok = await state.update(
        id: widget.transaction!.id!,
        amount: amount,
        category: _selectedCategory!,
        notes: notes,
        merchant: merchant,
        dateMillis: _date.millisecondsSinceEpoch,
        accountId: _selectedAccountId!,
      );
    } else {
      ok = await state.create(
        amount: amount,
        category: _selectedCategory!,
        notes: notes,
        merchant: merchant,
        dateMillis: _date.millisecondsSinceEpoch,
        accountId: _selectedAccountId!,
      );
    }

    if (!mounted) return;

    if (!ok) {
      ErrorToast.show(
        context,
        message: state.errorMessage ?? 'Operation failed',
      );
      state.clearError();
      return;
    }

    await state.loadAll(force: true);

    if (!mounted) return;

    if (isEdit) {
      Navigator.pop(context);
      return;
    }

    if (!addMore) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _amountController.clear();
      _notesController.clear();
      _merchantController.clear();
      _isExpense = false;
      _date = DateTime.now();
      _selectedCategory = _selectedCategory;
      _selectedAccountId = _selectedAccountId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountStateProvider);
    final categoryState = ref.watch(categoryStateProvider);

    final accounts = accountState.accounts;
    final categories = categoryState.categories;

    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    final isEdit = widget.transaction != null;

    final title = widget.transaction == null
        ? 'Add Transaction'
        : 'Edit Transaction';

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.deepPurpleAccent.withValues(alpha: .3);
                        }
                        return null;
                      }),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Income'),
                        icon: Icon(Icons.arrow_downward, color: Colors.green),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Expense'),
                        icon: Icon(Icons.arrow_upward, color: Colors.red),
                      ),
                    ],
                    selected: {_isExpense},
                    onSelectionChanged: (v) {
                      setState(() => _isExpense = v.first);
                    },
                  ),

                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width / 2 - 100,
                    ),
                    leading: const Icon(Icons.schedule),
                    title: Text(DateFormat.yMMMd().add_jm().format(_date)),
                    onTap: () async {
                      await _pickDate();
                      await _pickTime();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _merchantController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Merchant',
                      hintText: 'e.g. Tesco, Netflix, Uber',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownSearch<String>(
                    selectedItem: _selectedCategory,
                    items: (String filter, LoadProps? _) async {
                      if (filter.isEmpty) return categories;
                      return categories
                          .where(
                            (c) =>
                                c.toLowerCase().contains(filter.toLowerCase()),
                          )
                          .toList();
                    },
                    onChanged: (v) => setState(() => _selectedCategory = v),
                    popupProps: PopupProps.menu(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.33,
                      ),
                      showSearchBox: true,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          labelText: 'Search categories...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedAccountId,
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes/Memo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isEdit)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (accountState.loading || categoryState.loading)
                            ? null
                            : () => _saveTransaction(addMore: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent[700],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save'),
                      ),
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed:
                                (accountState.loading || categoryState.loading)
                                ? null
                                : () => _saveTransaction(addMore: false),
                            child: const Text('Save'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (accountState.loading || categoryState.loading)
                                ? null
                                : () => _saveTransaction(addMore: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurpleAccent[700],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Save and add more',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  if (categoryState.loading && categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: CircularProgressIndicator(),
                    ),

                  if (categoryState.errorMessage != null && categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        categoryState.errorMessage!,
                        style: TextStyle(color: Colors.red[600]),
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
