import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sloth_ledger/app/bootstrapbill/startup_provider.dart';
import 'package:sloth_ledger/domain/transactions/transaction.dart';
import 'package:sloth_ledger/features/ledger/ledger.dart';

import 'package:sloth_ledger/features/ledger/utils/relative_labels.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  int? _accountId; // null = all
  String? _category; // null = all
  bool _showSearch = false;

  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  String _queryRaw = '';
  String _queryApplied = '';

  static const _debounceMs = 50;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(transactionStateProvider).loadMore();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionStateProvider).recent(limit: 25);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocus.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadCurrentLedgerQuery() {
    ref
        .read(transactionStateProvider)
        .loadFiltered(
          accountId: _accountId,
          category: _category,
          searchQuery: _queryApplied,
        );
  }

  void _onSearchChanged(String v) {
    _queryRaw = v;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: _debounceMs), () {
      if (!mounted) return;
      setState(() => _queryApplied = _queryRaw);
      _loadCurrentLedgerQuery();
    });
  }

  void _closeSearch() {
    setState(() {
      _showSearch = false;
      _queryRaw = '';
      _queryApplied = '';
      _searchController.clear();
    });
    _loadCurrentLedgerQuery();
  }

  void _openFilters(BuildContext context, WidgetRef ref) {
    final accountState = ref.read(accountStateProvider);
    final categoryState = ref.read(categoryStateProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        int? accountId = _accountId;
        String? category = _category;

        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int?>(
                      initialValue: accountId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All accounts'),
                        ),
                        ...accountState.accounts.map(
                          (a) => DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setSheet(() => accountId = v),
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String?>(
                      initialValue: category,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All categories'),
                        ),
                        ...categoryState.categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c,
                            child: Text(c),
                          ),
                        ),
                      ],
                      onChanged: (v) => setSheet(() => category = v),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _accountId = null;
                                _category = null;
                              });
                              _loadCurrentLedgerQuery();
                              Navigator.pop(context);
                            },
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _accountId = accountId;
                                _category = category;
                              });
                              _loadCurrentLedgerQuery();
                              Navigator.pop(context);
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Map<DateTime, List<SlothTransaction>> _groupByDay(
    List<SlothTransaction> txns,
  ) {
    final map = <DateTime, List<SlothTransaction>>{};

    for (final txn in txns) {
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      map.putIfAbsent(day, () => []).add(txn);
    }

    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {
      for (final k in keys)
        k: (map[k]!..sort((a, b) => b.date.compareTo(a.date))),
    };
  }

  static String _normalizeQuery(String q) {
    return q.trim().toLowerCase();
  }

  static String _digitsAndDot(String s) {
    final buf = StringBuffer();
    for (final ch in s.characters) {
      if ((ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) ||
          ch == '.' ||
          ch == '-') {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  bool _matchesAmount(String query, SlothTransaction t) {
    final q = _digitsAndDot(query);
    if (q.isEmpty) return false;

    // If the user typed a number, match against common amount formats.
    final amt = t.amount;
    final amtAbs = amt.abs();

    // canonical formats
    final a1 = amt.toStringAsFixed(2); // "-12.50"
    final a2 = amtAbs.toStringAsFixed(2); // "12.50"
    final a3 = amt.toString(); // "-12.5" style
    final a4 = amtAbs.toString(); // "12.5"

    return a1.contains(q) || a2.contains(q) || a3.contains(q) || a4.contains(q);
  }

  bool _matchesDate(String query, DateTime d) {
    final q = _normalizeQuery(query);
    if (q.isEmpty) return false;

    // Provide multiple searchable date formats.
    final f1 = DateFormat.yMMMd().format(d).toLowerCase(); // "Feb 6, 2026"
    final f2 = DateFormat.yMd().format(d).toLowerCase(); // locale numeric
    final f3 = DateFormat('yyyy-MM-dd').format(d).toLowerCase();
    final f4 = DateFormat('yyyy-MM').format(d).toLowerCase();
    final f5 = DateFormat('MMMM').format(d).toLowerCase(); // "february"
    final f6 = DateFormat('MMM').format(d).toLowerCase(); // "feb"
    final f7 = DateFormat('yyyy').format(d).toLowerCase();

    final hay = '$f1 $f2 $f3 $f4 $f5 $f6 $f7';
    return hay.contains(q);
  }

  List<SlothTransaction> _applySearch(
    List<SlothTransaction> txns,
    AccountState accountState,
  ) {
    final q = _normalizeQuery(_queryApplied);
    if (q.isEmpty) return txns;

    return txns.where((t) {
      final accountName =
          accountState.byId(t.accountId)?.name ?? 'Account ${t.accountId}';

      final textHaystack = <String>[
        t.category,
        t.merchant ?? '',
        t.notes ?? '',
        accountName,
      ].join(' ').toLowerCase();

      final textMatch = textHaystack.contains(q);

      final amountMatch = _matchesAmount(q, t);

      final dateMatch = _matchesDate(q, t.date);

      return textMatch || amountMatch || dateMatch;
    }).toList();
  }

  @override
  Listener build(BuildContext context) {
    final txnState = ref.watch(transactionStateProvider);
    final settings = ref.watch(settingsStateProvider).settings;
    final symbol = settings.currencySymbol;

    final accountState = ref.watch(accountStateProvider);

    final base = txnState.all;

    final hasSearch = _normalizeQuery(_queryApplied).isNotEmpty;
    final hasFilters = _accountId != null || _category != null;
    final isTrulyEmpty = txnState.all.isEmpty;

    final searched = _applySearch(base, accountState);
    final collapsed = collapseTransfers(searched, accountState);
    final groups = _groupByDay(collapsed);

    final days = groups.keys.toList();

    final hasActiveFilters =
        _accountId != null ||
        _category != null ||
        _normalizeQuery(_queryApplied).isNotEmpty;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        FocusManager.instance.primaryFocus?.unfocus();

        if (_showSearch) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _showSearch = false);
            }
          });
        }
      },

      child: Scaffold(
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  focusNode: _searchFocus,
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText:
                        'Search merchant, category, notes, account, amount, date...',
                    border: InputBorder.none,
                  ),
                  onChanged: _onSearchChanged,
                  onTapOutside: (_) => _searchFocus.unfocus(),
                )
              : const Text('Ledger'),
          actions: [
            IconButton(
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              tooltip: _showSearch ? 'Close search' : 'Search',
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                });

                if (_showSearch) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _searchFocus.requestFocus();
                  });
                } else {
                  _closeSearch();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _openFilters(context, ref),
              tooltip: 'Filter',
            ),
            if (txnState.refreshingAll)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            if (hasActiveFilters)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_accountId != null)
                      Chip(
                        label: Text(
                          'Account: ${accountState.byId(_accountId!)?.name ?? _accountId}',
                        ),
                        onDeleted: () => setState(() => _accountId = null),
                      ),
                    if (_category != null)
                      Chip(
                        label: Text('Category: $_category'),
                        onDeleted: () => setState(() => _category = null),
                      ),
                    if (_normalizeQuery(_queryApplied).isNotEmpty)
                      Chip(
                        label: Text('Search: ${_queryApplied.trim()}'),
                        onDeleted: () {
                          setState(() {
                            _queryRaw = '';
                            _queryApplied = '';
                            _searchController.clear();
                          });
                        },
                      ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(transactionStateProvider).loadAll(force: true);
                  if (!context.mounted) return;
                  await ref.read(balanceStateProvider).load(force: true);
                },
                child: Builder(
                  builder: (context) {
                    // LOADING (first load only)
                    if (!txnState.allLoaded && txnState.loading) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 220),
                          Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }

                    // ERROR (first load only)
                    if (!txnState.allLoaded && txnState.errorMessage != null) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 180),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              txnState.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    }

                    // EMPTY (filter-aware)
                    if (collapsed.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.18,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Center(
                              heightFactor: 1.5,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 52,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),

                                  if (isTrulyEmpty &&
                                      !hasFilters &&
                                      !hasSearch) ...[
                                    const Text(
                                      'No transactions yet...',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Your ledger will show all income and expenses here.\n'
                                      'Add your first transaction to get started.',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        height: 1.35,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 18),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add transaction'),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          builder: (_) =>
                                              const AddTransactionModal(),
                                        );
                                      },
                                    ),
                                  ] else if (hasFilters && !hasSearch) ...[
                                    const Text(
                                      'No matching transactions',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Your current filters exclude all transactions.',
                                      style: TextStyle(color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _accountId = null;
                                          _category = null;
                                        });
                                      },
                                      child: const Text('Clear filters'),
                                    ),
                                  ] else if (hasSearch) ...[
                                    const Text(
                                      'No search results',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Try a different keyword, amount, or date.',
                                      style: TextStyle(color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _queryRaw = '';
                                          _queryApplied = '';
                                          _searchController.clear();
                                        });
                                      },
                                      child: const Text('Clear search'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final txns = groups[day]!;
                        return _LedgerDayGroup(
                          day: day,
                          txns: txns,
                          currencySymbol: symbol,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerDayGroup extends StatelessWidget {
  const _LedgerDayGroup({
    required this.day,
    required this.txns,
    required this.currencySymbol,
  });

  final DateTime day;
  final List<SlothTransaction> txns;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final total = txns.fold<double>(0, (sum, t) => sum + t.amount);

    final rel = relativeDayLabel(day);
    final full = DateFormat.yMMMMd().format(day);

    final label = (rel == full) ? full : '$rel • $full';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '$currencySymbol${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: total < 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ),
        ...txns.map(
          (t) => TransactionRow(txn: t, currencySymbol: currencySymbol),
        ),
        const Divider(height: 16),
      ],
    );
  }
}
