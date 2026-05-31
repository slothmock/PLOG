class AppStrings {
  // Titles
  static const appName = 'PLOG';
  static const overviewTitle = 'Home';
  static const ledgerTitle = 'Ledger';
  static const accountsTitle = 'Accounts';
  static const subscriptionsTitle = 'Subscriptions';
  static const budgetTitle = 'Budgeting';
  static const investingTitle = 'Investing';
  static const cryptoTitle = 'Crypto';
  static const settingsTitle = 'Settings';

  static const supportSlothKofi = 'Support Me on Ko-fi!';
  static const thanksForSupport = 'Thanks for your support!';

  // Common
  static const cancel = 'Cancel';
  static const save = 'Save';
  static const add = 'Add';
  static const edit = 'Edit';
  static const delete = 'Delete';
  static const refresh = 'Refresh';
  static const refreshing = 'Refreshing...';

  // Accounts
  static const noAccounts = 'No accounts yet.';
  static const addAccount = 'Add Account';
  static const editAccount = 'Edit Account';
  static const accountName = 'Account Name';
  static const startingBalance = 'Starting Balance';

  // Balance
  static const invalidStartBalance = 'Enter a valid starting balance';
  static const totalCashLabel = 'Total Funds';
  static const investmentTypeLabel = 'Investments';
  static const cryptoTypeLabel = 'Crypto';
  static const monthNetLabel = 'This Month';
  static const netWorthLabel = 'Net Worth';

  // Transactions
  static const recentTransactions = 'Recent Transactions';
  static const addTransaction = 'Add Transaction';
  static const editTransaction = 'Edit Transaction';
  static const noRecentTransactionsTitle =
      "Add your first transaction\n by pressing the '+' button below!";
  static const noTransactionsYetTitle = 'No transactions yet...';
  static const noTransactionsYetBody =
      'Your ledger will show all income and expenses here.\n'
      'Add your first transaction to get started.';

  static const noMatchingTransactionsTitle = 'No matching transactions';
  static const noMatchingTransactionsBody =
      'Your current filters exclude all transactions.';

  static const noSearchResultsTitle = 'No search results';
  static const noSearchResultsBody =
      'Try a different keyword, amount, or date.';

  static String accountChip(String name) => 'Account: $name';
  static String categoryChip(String name) => 'Category: $name';
  static String searchChip(String q) => 'Search: $q';

  // Subscriptions
  static const addSubscription = 'Add Subscription';
  static const editSubscription = 'Edit Subscription';
  static const noSubscriptions = 'No subscriptions yet...';
  static const subsNotFound = 'No subscriptions found. Try adding one!';
  static const subsRefreshed = 'Subscriptions refreshed!';
  static const addSubsBody =
      'Track recurring bills like Netflix, Spotify, iCloud.\n'
      'Add your first subscription to see upcoming payments.';

  static const subActive = 'Active';
  static const subDueSoon = 'Due Soon';
  static const subDueLater = 'Later';
  static const subPaused = 'Paused';
  static const subOverdue = 'Overdue';

  // Settings
  static const categoriesTitle = 'Categories';
  static const deleteHistoryTitle = 'Delete transaction history';
  static const dataTitle = 'Data';
  static const deleteHistorySubtitle = 'Removes all transactions only';
  static const reset = 'Reset';
  static const resetAppTitle = 'Reset app';
  static const resetAppSubtitle = 'Deletes all data and resets the app';
  static const aboutTitle = 'About';
  static const versionTitle = 'Version';
  static const deleteTransactionsQuestion = 'Delete transaction history?';
  static const deleteTransactionsBody =
      'This will permanently delete all transactions.\n\n'
      'Accounts, categories, subscriptions, and settings will remain.';
  static const historyDeleted = 'Transaction history deleted';
  static const resetAppQuestion = 'Reset app?';
  static const resetAppBody =
      'This will permanently delete ALL data:\n\n'
      '• Accounts\n'
      '• Transactions\n'
      '• Subscriptions\n'
      '• Categories\n'
      '• Settings\n\n'
      'This cannot be undone.';
  static const resetComplete = 'App reset complete';
  static const resetFail = 'App reset failed';
}
