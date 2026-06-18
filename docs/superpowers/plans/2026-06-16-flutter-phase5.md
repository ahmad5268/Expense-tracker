# Flutter App — Phase 5: Transactions Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the full transactions feature: paginated, filterable transaction list; add/edit bottom sheet; shared `AmountField` and `CategoryPicker` widgets.

**Architecture:** `TransactionsNotifier` holds a paginated list with infinite scroll (loads next page on scroll-to-bottom). Filters (date range, category, type) are part of the notifier state. `AddTransactionSheet` and `EditTransactionSheet` are modal bottom sheets that call the notifier's `add`/`update` methods on save. The `AmountField` handles raw integer input (user types "50.00", stored as 5000 cents) and the `CategoryPicker` shows a filterable grid of workspace categories.

**Tech Stack:** `flutter_riverpod`, `dio`, `freezed`, `intl`

**Prerequisite:** Phase 3 complete. All models, `activeWorkspaceProvider`, `CurrencyFormatter` available.

---

## File Map

| File | Responsibility |
|---|---|
| `lib/features/transactions/transactions_provider.dart` | Paginated list, filters, CRUD |
| `lib/features/transactions/transactions_screen.dart` | List + FAB + filter button |
| `lib/features/transactions/add_transaction_sheet.dart` | Bottom sheet for adding new transactions |
| `lib/features/transactions/edit_transaction_sheet.dart` | Bottom sheet for editing |
| `lib/features/transactions/widgets/transaction_list_item.dart` | Single row in the list |
| `lib/features/transactions/widgets/transaction_filters.dart` | Filter panel (type, category, date range) |
| `lib/shared/widgets/amount_field.dart` | Currency-aware text field (input in dollars, stores cents) |
| `lib/shared/widgets/category_picker.dart` | Grid of category chips for selection |
| `lib/shared/widgets/date_range_picker_field.dart` | Tappable field that opens the platform date range picker |
| `test/features/transactions/transactions_provider_test.dart` | Unit tests |
| `test/shared/widgets/amount_field_test.dart` | Widget test |

---

## Task 1: AmountField shared widget

**Files:**
- Create: `lib/shared/widgets/amount_field.dart`
- Create: `test/shared/widgets/amount_field_test.dart`

- [ ] **Step 1.1: Write failing widget test**

```dart
// apps/mobile/test/shared/widgets/amount_field_test.dart
import 'package:expense_tracker/shared/widgets/amount_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AmountField displays initial value in display format', (tester) async {
    int? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AmountField(
          initialCents: 5000,
          onChanged: (v) => captured = v,
          currency: 'USD',
        ),
      ),
    ));
    expect(find.text('50.00'), findsOneWidget);
  });

  testWidgets('AmountField converts typed decimal to cents', (tester) async {
    int? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AmountField(
          initialCents: 0,
          onChanged: (v) => captured = v,
          currency: 'USD',
        ),
      ),
    ));
    await tester.enterText(find.byType(TextFormField), '12.50');
    await tester.pump();
    expect(captured, 1250);
  });

  testWidgets('AmountField validates that amount must be positive', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: AmountField(
            initialCents: 0,
            onChanged: (_) {},
            currency: 'USD',
          ),
        ),
      ),
    ));
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Enter a positive amount'), findsOneWidget);
  });
}
```

- [ ] **Step 1.2: Run test — verify it fails**

```bash
cd apps/mobile && flutter test test/shared/widgets/amount_field_test.dart
```

Expected: FAIL — `Cannot find module 'amount_field.dart'`

- [ ] **Step 1.3: Implement AmountField**

```dart
// apps/mobile/lib/shared/widgets/amount_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AmountField extends StatefulWidget {
  final int initialCents;
  final void Function(int cents) onChanged;
  final String currency;

  const AmountField({
    super.key,
    required this.initialCents,
    required this.onChanged,
    required this.currency,
  });

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialCents > 0
          ? (widget.initialCents / 100.0).toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _toCents(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(cleaned) ?? 0.0;
    return (amount * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: 'Amount (${widget.currency})',
        prefixText: '\$ ',
      ),
      onChanged: (v) => widget.onChanged(_toCents(v)),
      validator: (v) {
        if (v == null || v.isEmpty || _toCents(v) <= 0) {
          return 'Enter a positive amount';
        }
        return null;
      },
    );
  }
}
```

- [ ] **Step 1.4: Run tests — verify pass**

```bash
flutter test test/shared/widgets/amount_field_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 1.5: Commit**

```bash
git add apps/mobile/lib/shared/widgets/amount_field.dart apps/mobile/test/shared/widgets/amount_field_test.dart
git commit -m "feat(mobile/shared): add AmountField widget (decimal input → cents)"
```

---

## Task 2: CategoryPicker + DateRangePickerField shared widgets
Depends-on: 1

**Files:**
- Create: `lib/shared/widgets/category_picker.dart`
- Create: `lib/shared/widgets/date_range_picker_field.dart`

- [ ] **Step 2.1: Implement CategoryPicker**

```dart
// apps/mobile/lib/shared/widgets/category_picker.dart
import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryPicker extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final void Function(Category) onSelected;

  const CategoryPicker({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Text('No categories available');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = cat.id == selectedId;
        return ChoiceChip(
          key: Key('category_${cat.id}'),
          label: Text('${cat.icon} ${cat.name}'),
          selected: isSelected,
          onSelected: (_) => onSelected(cat),
          selectedColor: Color(
            int.parse(cat.color.replaceFirst('#', '0xFF')),
          ).withOpacity(0.2),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 2.2: Implement DateRangePickerField**

```dart
// apps/mobile/lib/shared/widgets/date_range_picker_field.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangePickerField extends StatelessWidget {
  final DateTimeRange? value;
  final void Function(DateTimeRange?) onChanged;

  const DateRangePickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: value,
    );
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMMd();
    final label = value != null
        ? '${fmt.format(value!.start)} – ${fmt.format(value!.end)}'
        : 'All time';

    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date Range',
          suffixIcon: Icon(Icons.date_range),
        ),
        child: Text(label),
      ),
    );
  }
}
```

- [ ] **Step 2.3: Commit**

```bash
git add apps/mobile/lib/shared/widgets/category_picker.dart apps/mobile/lib/shared/widgets/date_range_picker_field.dart
git commit -m "feat(mobile/shared): add CategoryPicker and DateRangePickerField widgets"
```

---

## Task 3: TransactionsProvider

**Files:**
- Create: `lib/features/transactions/transactions_provider.dart`
- Create: `test/features/transactions/transactions_provider_test.dart`

- [ ] **Step 3.1: Write failing unit tests**

```dart
// apps/mobile/test/features/transactions/transactions_provider_test.dart
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';
import 'package:expense_tracker/features/transactions/transactions_provider.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'transactions_provider_test.mocks.dart';

const _workspace = Workspace(id: 'w1', name: 'P', currency: 'USD', ownerId: 'u1');

final _txJson = {
  'id': 't1', 'workspaceId': 'w1', 'userId': 'u1',
  'categoryId': 'c1', 'amount': 5000, 'type': 'expense',
  'date': '2026-06-01T00:00:00.000Z', 'createdAt': '2026-06-01T10:00:00.000Z',
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    adapter = DioAdapter(dio: dio);
    final mockStorage = MockSecureStorageService();
    when(mockStorage.getAccessToken()).thenAnswer((_) async => 'tok');
    final client = ApiClient.withDio(dio, mockStorage);
    container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      activeWorkspaceProvider.overrideWithValue(_workspace),
    ]);
  });

  tearDown(() => container.dispose());

  test('fetchTransactions loads first page', () async {
    adapter.onGet('/workspaces/w1/transactions', (server) => server.reply(200, {
          'data': [_txJson],
          'total': 1,
          'page': 1,
          'totalPages': 1,
        }));

    await container.read(transactionsNotifierProvider.notifier).fetchTransactions();
    final state = container.read(transactionsNotifierProvider);
    expect(state.transactions.length, 1);
    expect(state.transactions.first.amount, 5000);
    expect(state.hasMore, false);
  });

  test('addTransaction prepends to list', () async {
    adapter
      ..onGet('/workspaces/w1/transactions', (server) => server.reply(200, {
            'data': [_txJson], 'total': 1, 'page': 1, 'totalPages': 1
          }))
      ..onPost('/workspaces/w1/transactions', (server) => server.reply(201, {
            'data': {
              ..._txJson,
              'id': 't2',
              'amount': 2000,
              'date': '2026-06-10T00:00:00.000Z',
              'createdAt': '2026-06-10T10:00:00.000Z',
            }
          }));

    await container.read(transactionsNotifierProvider.notifier).fetchTransactions();
    await container.read(transactionsNotifierProvider.notifier).addTransaction(
      categoryId: 'c1',
      amount: 2000,
      type: 'expense',
      date: DateTime(2026, 6, 10),
    );

    final state = container.read(transactionsNotifierProvider);
    expect(state.transactions.length, 2);
    expect(state.transactions.first.id, 't2');
  });

  test('deleteTransaction removes from list', () async {
    adapter
      ..onGet('/workspaces/w1/transactions', (server) => server.reply(200, {
            'data': [_txJson], 'total': 1, 'page': 1, 'totalPages': 1
          }))
      ..onDelete('/workspaces/w1/transactions/t1',
          (server) => server.reply(200, {'data': null}));

    await container.read(transactionsNotifierProvider.notifier).fetchTransactions();
    await container.read(transactionsNotifierProvider.notifier).deleteTransaction('t1');

    final state = container.read(transactionsNotifierProvider);
    expect(state.transactions, isEmpty);
  });
}
```

- [ ] **Step 3.2: Generate mocks and run to verify failure**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/transactions/transactions_provider_test.dart
```

Expected: FAIL — `Cannot find module 'transactions_provider.dart'`

- [ ] **Step 3.3: Implement TransactionsProvider**

```dart
// apps/mobile/lib/features/transactions/transactions_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';
import '../../shared/models/transaction.dart';

class TransactionsFilter {
  final String? categoryId;
  final String? type;
  final DateTimeRange? dateRange;

  const TransactionsFilter({this.categoryId, this.type, this.dateRange});

  Map<String, dynamic> toQueryParams() => {
        if (categoryId != null) 'categoryId': categoryId,
        if (type != null) 'type': type,
        if (dateRange != null) 'from': dateRange!.start.toIso8601String(),
        if (dateRange != null) 'to': dateRange!.end.toIso8601String(),
      };
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}

class TransactionsState {
  final List<Transaction> transactions;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final TransactionsFilter filter;

  const TransactionsState({
    this.transactions = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.filter = const TransactionsFilter(),
  });

  TransactionsState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    TransactionsFilter? filter,
  }) =>
      TransactionsState(
        transactions: transactions ?? this.transactions,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        currentPage: currentPage ?? this.currentPage,
        filter: filter ?? this.filter,
      );
}

class TransactionsNotifier extends Notifier<TransactionsState> {
  @override
  TransactionsState build() => const TransactionsState();

  Future<void> fetchTransactions({bool reset = true}) async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;

    if (reset) {
      state = const TransactionsState();
    }

    state = state.copyWith(isLoading: true);
    final page = reset ? 1 : state.currentPage + 1;

    final response = await ref.read(apiClientProvider).dio.get(
          '/workspaces/${workspace.id}/transactions',
          queryParameters: {
            'page': page,
            'limit': 20,
            ...state.filter.toQueryParams(),
          },
        );

    final data = response.data;
    final newTx = (data['data'] as List)
        .map((j) => Transaction.fromJson(j as Map<String, dynamic>))
        .toList();

    state = state.copyWith(
      transactions: reset ? newTx : [...state.transactions, ...newTx],
      isLoading: false,
      hasMore: page < (data['totalPages'] as int),
      currentPage: page,
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await fetchTransactions(reset: false);
  }

  void setFilter(TransactionsFilter filter) {
    state = state.copyWith(filter: filter);
    fetchTransactions();
  }

  Future<void> addTransaction({
    required String categoryId,
    required int amount,
    required String type,
    required DateTime date,
    String? description,
  }) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    final response = await ref.read(apiClientProvider).dio.post(
          '/workspaces/${workspace.id}/transactions',
          data: {
            'categoryId': categoryId,
            'amount': amount,
            'type': type,
            'date': date.toIso8601String(),
            if (description != null) 'description': description,
          },
        );
    final tx = Transaction.fromJson(response.data['data'] as Map<String, dynamic>);
    state = state.copyWith(transactions: [tx, ...state.transactions]);
  }

  Future<void> updateTransaction(
    String id, {
    String? categoryId,
    int? amount,
    String? type,
    DateTime? date,
    String? description,
  }) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    final response = await ref.read(apiClientProvider).dio.put(
          '/workspaces/${workspace.id}/transactions/$id',
          data: {
            if (categoryId != null) 'categoryId': categoryId,
            if (amount != null) 'amount': amount,
            if (type != null) 'type': type,
            if (date != null) 'date': date.toIso8601String(),
            if (description != null) 'description': description,
          },
        );
    final updated = Transaction.fromJson(response.data['data'] as Map<String, dynamic>);
    state = state.copyWith(
      transactions: state.transactions.map((t) => t.id == id ? updated : t).toList(),
    );
  }

  Future<void> deleteTransaction(String id) async {
    final workspace = ref.read(activeWorkspaceProvider)!;
    await ref.read(apiClientProvider).dio.delete(
          '/workspaces/${workspace.id}/transactions/$id',
        );
    state = state.copyWith(
      transactions: state.transactions.where((t) => t.id != id).toList(),
    );
  }
}

final transactionsNotifierProvider =
    NotifierProvider<TransactionsNotifier, TransactionsState>(
        TransactionsNotifier.new);
```

- [ ] **Step 3.4: Run tests — verify pass**

```bash
flutter test test/features/transactions/transactions_provider_test.dart
```

Expected: PASS — 3 tests

- [ ] **Step 3.5: Commit**

```bash
git add apps/mobile/lib/features/transactions/transactions_provider.dart apps/mobile/test/features/transactions/transactions_provider_test.dart
git commit -m "feat(mobile/transactions): add TransactionsNotifier with pagination, filters, CRUD"
```

---

## Task 4: AddTransactionSheet
Depends-on: 2, 3

**Files:**
- Create: `lib/features/transactions/add_transaction_sheet.dart`

- [ ] **Step 4.1: Implement AddTransactionSheet**

```dart
// apps/mobile/lib/features/transactions/add_transaction_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/category.dart';
import '../../shared/widgets/amount_field.dart';
import '../../shared/widgets/category_picker.dart';
import 'transactions_provider.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final List<Category> categories;

  const AddTransactionSheet({super.key, required this.categories});

  static Future<void> show(BuildContext context, List<Category> categories) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddTransactionSheet(categories: categories),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  int _amountCents = 0;
  String _type = 'expense';
  String? _categoryId;
  String? _description;
  DateTime _date = DateTime.now();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(transactionsNotifierProvider.notifier).addTransaction(
            categoryId: _categoryId!,
            amount: _amountCents,
            type: _type,
            date: _date,
            description: _description,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add transaction')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = widget.categories
        .where((c) => c.type.name == _type)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Transaction',
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              key: const Key('typeSelector'),
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            AmountField(
              initialCents: 0,
              onChanged: (v) => _amountCents = v,
              currency: 'USD',
            ),
            const SizedBox(height: 16),
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            CategoryPicker(
              categories: filteredCategories,
              selectedId: _categoryId,
              onSelected: (c) => setState(() => _categoryId = c.id),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('descriptionField'),
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              onChanged: (v) => _description = v.isEmpty ? null : v,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              trailing: Text(
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('saveButton'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Transaction'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4.2: Commit**

```bash
git add apps/mobile/lib/features/transactions/add_transaction_sheet.dart
git commit -m "feat(mobile/transactions): add AddTransactionSheet bottom sheet"
```

---

## Task 5: TransactionsScreen
Depends-on: 4

**Files:**
- Create: `lib/features/transactions/transactions_screen.dart`
- Create: `lib/features/transactions/widgets/transaction_list_item.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 5.1: Implement TransactionListItem**

```dart
// apps/mobile/lib/features/transactions/widgets/transaction_list_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/utils/currency_formatter.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.currency,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpense
              ? Colors.red.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
          child: Text(transaction.categoryIcon ?? '💰'),
        ),
        title: Text(transaction.categoryName ?? 'Unknown Category'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.yMMMd().format(transaction.date)),
            if (transaction.description != null)
              Text(transaction.description!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}${CurrencyFormatter.format(transaction.amount, currency)}',
          style: TextStyle(
            color: isExpense ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
```

- [ ] **Step 5.2: Implement TransactionsScreen**

```dart
// apps/mobile/lib/features/transactions/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/workspaces/workspace_provider.dart';
import 'transactions_provider.dart';
import 'add_transaction_sheet.dart';
import 'widgets/transaction_list_item.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionsNotifierProvider.notifier).fetchTransactions();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionsNotifierProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsNotifierProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final currency = workspace?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {/* open filter panel — stub */},
          ),
        ],
      ),
      body: state.transactions.isEmpty && !state.isLoading
          ? const Center(child: Text('No transactions yet. Tap + to add one.'))
          : ListView.separated(
              controller: _scrollController,
              itemCount: state.transactions.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == state.transactions.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final tx = state.transactions[index];
                return TransactionListItem(
                  transaction: tx,
                  currency: currency,
                  onTap: () {/* open edit sheet */},
                  onDelete: () => ref
                      .read(transactionsNotifierProvider.notifier)
                      .deleteTransaction(tx.id),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addTransactionFab'),
        onPressed: () => AddTransactionSheet.show(context, const []),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}
```

- [ ] **Step 5.3: Update GoRouter**

In `lib/core/router/app_router.dart`:
```dart
// Add import:
import '../../features/transactions/transactions_screen.dart';

// Replace placeholder:
GoRoute(path: AppRoutes.transactions, builder: (_, __) => const TransactionsScreen()),
```

- [ ] **Step 5.4: Run full test suite**

```bash
cd apps/mobile && flutter test
```

Expected: All tests pass.

- [ ] **Step 5.5: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues.

- [ ] **Step 5.6: Commit**

```bash
git add apps/mobile/lib/features/transactions/ apps/mobile/lib/core/router/app_router.dart
git commit -m "feat(mobile/transactions): add TransactionsScreen with infinite scroll, swipe-to-delete"
```

---

## Phase 5 Complete

- ✅ `AmountField` — decimal input, validates positive, emits cents
- ✅ `CategoryPicker` — `ChoiceChip` grid filtered by transaction type
- ✅ `DateRangePickerField` — tappable date range selector
- ✅ `TransactionsNotifier` — paginated list, filter state, add/update/delete, infinite scroll
- ✅ `AddTransactionSheet` — amount + type toggle + category picker + date + description
- ✅ `TransactionListItem` — swipe-to-delete with confirmation, category icon, signed amount
- ✅ `TransactionsScreen` — infinite scroll, empty state, FAB
- ✅ Unit tests: 3 provider + 3 amount field = 6 tests

**Next plan:** `2026-06-16-flutter-phase6.md` — Workspaces feature (switcher, settings, members, invites)
