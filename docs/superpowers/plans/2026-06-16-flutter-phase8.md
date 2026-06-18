# Flutter App — Phase 8: Reports + Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Reports screen with 6 chart tabs (line, pie, bar × 2, heatmap, summary), an export button that downloads CSV/PDF from the API, and a `ReportsProvider` that fetches all analytics data.

**Architecture:** `ReportsNotifier` fetches all 6 report endpoints in parallel when the screen opens and caches data per workspace + month. Each tab is a separate widget consuming the notifier state. CSV/PDF exports call the API and save the response to the device using `url_launcher` (web) or write to temporary file (mobile). FL Chart is used for all chart rendering.

**Tech Stack:** `fl_chart ^0.68`, `flutter_riverpod`, `url_launcher`, `intl`

**Prerequisite:** Phase 5 complete. `activeWorkspaceProvider`, `CurrencyFormatter`, `Budget` model available.

---

## File Map

| File | Responsibility |
|---|---|
| `lib/features/reports/reports_provider.dart` | Fetches all 6 report endpoints, holds state |
| `lib/features/reports/reports_screen.dart` | TabBar with 6 tabs |
| `lib/features/reports/charts/summary_tab.dart` | Income/expense/net summary for selected month |
| `lib/features/reports/charts/trends_chart.dart` | Line chart: monthly income/expense for 12 months |
| `lib/features/reports/charts/category_chart.dart` | Pie chart + table: expense by category |
| `lib/features/reports/charts/budget_vs_actual_chart.dart` | Horizontal bar chart: budget vs actual per budget |
| `lib/features/reports/charts/year_over_year_chart.dart` | Bar chart: this year vs last year by month |
| `lib/features/reports/charts/heatmap_chart.dart` | Grid heatmap: daily expense totals |
| `lib/features/reports/export_button.dart` | Download CSV or PDF from API |
| `lib/core/router/app_router.dart` | Updated: reports route uses ReportsScreen |
| `test/features/reports/reports_provider_test.dart` | Unit tests |

---

## Task 1: ReportsProvider

**Files:**
- Create: `lib/features/reports/reports_provider.dart`
- Create: `test/features/reports/reports_provider_test.dart`

- [ ] **Step 1.1: Write failing unit tests**

```dart
// apps/mobile/test/features/reports/reports_provider_test.dart
import 'package:dio/dio.dart';
import 'package:expense_tracker/core/api/api_client.dart';
import 'package:expense_tracker/core/auth/secure_storage.dart';
import 'package:expense_tracker/features/reports/reports_provider.dart';
import 'package:expense_tracker/features/workspaces/workspace_provider.dart';
import 'package:expense_tracker/shared/models/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<SecureStorageService>()])
import 'reports_provider_test.mocks.dart';

const _workspace = Workspace(id: 'w1', name: 'P', currency: 'USD', ownerId: 'u1');

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

  test('fetchReports loads summary data', () async {
    final now = DateTime.now();
    adapter
      ..onGet('/workspaces/w1/reports/summary',
          (server) => server.reply(200, {'data': {'totalIncome': 100000, 'totalExpense': 75000, 'net': 25000}}))
      ..onGet('/workspaces/w1/reports/by-category',
          (server) => server.reply(200, {'data': []}))
      ..onGet('/workspaces/w1/reports/trends',
          (server) => server.reply(200, {'data': []}))
      ..onGet('/workspaces/w1/reports/budget-vs-actual',
          (server) => server.reply(200, {'data': []}))
      ..onGet('/workspaces/w1/reports/year-over-year',
          (server) => server.reply(200, {'data': []}))
      ..onGet('/workspaces/w1/reports/heatmap',
          (server) => server.reply(200, {'data': []}));

    await container.read(reportsNotifierProvider.notifier).fetchReports(year: now.year, month: now.month);
    final state = container.read(reportsNotifierProvider);
    expect(state.totalIncome, 100000);
    expect(state.totalExpense, 75000);
    expect(state.net, 25000);
    expect(state.isLoading, false);
  });
}
```

- [ ] **Step 1.2: Generate mocks and run to verify failure**

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/reports/reports_provider_test.dart
```

Expected: FAIL — `Cannot find module 'reports_provider.dart'`

- [ ] **Step 1.3: Implement ReportsProvider**

```dart
// apps/mobile/lib/features/reports/reports_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';

class CategorySpend {
  final String categoryId;
  final String categoryName;
  final int total;
  final int count;
  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.total,
    required this.count,
  });

  factory CategorySpend.fromJson(Map<String, dynamic> j) => CategorySpend(
        categoryId: j['categoryId'] as String,
        categoryName: j['categoryName'] as String,
        total: j['total'] as int,
        count: j['count'] as int,
      );
}

class TrendPoint {
  final int month;
  final String type;
  final int total;
  const TrendPoint({required this.month, required this.type, required this.total});
  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
        month: j['month'] as int,
        type: j['type'] as String,
        total: j['total'] as int,
      );
}

class BudgetVsActualRow {
  final String budgetId;
  final String? categoryName;
  final int budgetAmount;
  final int actualAmount;
  const BudgetVsActualRow({
    required this.budgetId,
    this.categoryName,
    required this.budgetAmount,
    required this.actualAmount,
  });
  factory BudgetVsActualRow.fromJson(Map<String, dynamic> j) => BudgetVsActualRow(
        budgetId: j['budgetId'] as String,
        categoryName: j['categoryName'] as String?,
        budgetAmount: j['budgetAmount'] as int,
        actualAmount: j['actualAmount'] as int,
      );
}

class HeatmapDay {
  final String day;
  final int total;
  const HeatmapDay({required this.day, required this.total});
  factory HeatmapDay.fromJson(Map<String, dynamic> j) =>
      HeatmapDay(day: j['day'] as String, total: j['total'] as int);
}

class ReportsState {
  final int totalIncome;
  final int totalExpense;
  final int net;
  final List<CategorySpend> byCategory;
  final List<TrendPoint> trends;
  final List<BudgetVsActualRow> budgetVsActual;
  final List<TrendPoint> yearOverYear;
  final List<HeatmapDay> heatmap;
  final bool isLoading;

  const ReportsState({
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.net = 0,
    this.byCategory = const [],
    this.trends = const [],
    this.budgetVsActual = const [],
    this.yearOverYear = const [],
    this.heatmap = const [],
    this.isLoading = false,
  });

  ReportsState copyWith({bool? isLoading}) =>
      ReportsState(
        totalIncome: totalIncome, totalExpense: totalExpense, net: net,
        byCategory: byCategory, trends: trends, budgetVsActual: budgetVsActual,
        yearOverYear: yearOverYear, heatmap: heatmap,
        isLoading: isLoading ?? this.isLoading,
      );
}

class ReportsNotifier extends Notifier<ReportsState> {
  @override
  ReportsState build() => const ReportsState();

  Future<void> fetchReports({required int year, required int month}) async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;

    state = state.copyWith(isLoading: true);
    final client = ref.read(apiClientProvider);
    final wid = workspace.id;

    final results = await Future.wait([
      client.dio.get('/workspaces/$wid/reports/summary',
          queryParameters: {'year': year, 'month': month}),
      client.dio.get('/workspaces/$wid/reports/by-category',
          queryParameters: {'year': year, 'month': month}),
      client.dio.get('/workspaces/$wid/reports/trends',
          queryParameters: {'year': year}),
      client.dio.get('/workspaces/$wid/reports/budget-vs-actual',
          queryParameters: {'year': year, 'month': month}),
      client.dio.get('/workspaces/$wid/reports/year-over-year'),
      client.dio.get('/workspaces/$wid/reports/heatmap',
          queryParameters: {'year': year}),
    ]);

    final summary = results[0].data['data'] as Map<String, dynamic>;
    state = ReportsState(
      totalIncome: summary['totalIncome'] as int,
      totalExpense: summary['totalExpense'] as int,
      net: summary['net'] as int,
      byCategory: (results[1].data['data'] as List)
          .map((j) => CategorySpend.fromJson(j as Map<String, dynamic>))
          .toList(),
      trends: (results[2].data['data'] as List)
          .map((j) => TrendPoint.fromJson(j as Map<String, dynamic>))
          .toList(),
      budgetVsActual: (results[3].data['data'] as List)
          .map((j) => BudgetVsActualRow.fromJson(j as Map<String, dynamic>))
          .toList(),
      yearOverYear: (results[4].data['data'] as List)
          .map((j) => TrendPoint.fromJson(j as Map<String, dynamic>))
          .toList(),
      heatmap: (results[5].data['data'] as List)
          .map((j) => HeatmapDay.fromJson(j as Map<String, dynamic>))
          .toList(),
      isLoading: false,
    );
  }
}

final reportsNotifierProvider =
    NotifierProvider<ReportsNotifier, ReportsState>(ReportsNotifier.new);
```

- [ ] **Step 1.4: Run tests — verify pass**

```bash
flutter test test/features/reports/reports_provider_test.dart
```

Expected: PASS — 1 test

- [ ] **Step 1.5: Commit**

```bash
git add apps/mobile/lib/features/reports/reports_provider.dart apps/mobile/test/features/reports/reports_provider_test.dart
git commit -m "feat(mobile/reports): add ReportsNotifier with parallel 6-endpoint fetch"
```

---

## Task 2: Charts — SummaryTab, TrendsChart, CategoryChart
Depends-on: 1

**Files:**
- Create: `lib/features/reports/charts/summary_tab.dart`
- Create: `lib/features/reports/charts/trends_chart.dart`
- Create: `lib/features/reports/charts/category_chart.dart`

- [ ] **Step 2.1: Implement SummaryTab**

```dart
// apps/mobile/lib/features/reports/charts/summary_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/workspaces/workspace_provider.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsNotifierProvider);
    final currency = ref.watch(activeWorkspaceProvider)?.currency ?? 'USD';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(label: 'Total Income', value: CurrencyFormatter.format(state.totalIncome, currency), color: Colors.green),
        const SizedBox(height: 12),
        _StatCard(label: 'Total Expenses', value: CurrencyFormatter.format(state.totalExpense, currency), color: Colors.red),
        const SizedBox(height: 12),
        _StatCard(
          label: 'Net Balance',
          value: CurrencyFormatter.format(state.net, currency),
          color: state.net >= 0 ? Colors.green : Colors.red,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(label),
          trailing: Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      );
}
```

- [ ] **Step 2.2: Implement TrendsChart (line chart)**

The `LineChartData` must use workspace-currency-aware compact labels on the Y axis and suppress top/right axes. Key configuration:

```dart
// apps/mobile/lib/features/reports/charts/trends_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class TrendsChart extends ConsumerWidget {
  const TrendsChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trends = ref.watch(reportsNotifierProvider).trends;

    if (trends.isEmpty) {
      return const Center(child: Text('No data for this period'));
    }

    final incomeByMonth = <int, double>{};
    final expenseByMonth = <int, double>{};
    for (final p in trends) {
      if (p.type == 'INCOME') {
        incomeByMonth[p.month] = (p.total / 100.0);
      } else {
        expenseByMonth[p.month] = (p.total / 100.0);
      }
    }

    final months = {for (var i = 1; i <= 12; i++) i};

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs Expenses (last 12 months)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Text(
                        DateFormat.MMM().format(DateTime(2026, value.toInt())),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Text(
                        CurrencyFormatter.compact(value.toInt()),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  // Suppress top and right axes — required per gap fix
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: months
                        .map((m) => FlSpot(m.toDouble(), incomeByMonth[m] ?? 0))
                        .toList(),
                    isCurved: true,
                    color: Colors.green,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: months
                        .map((m) => FlSpot(m.toDouble(), expenseByMonth[m] ?? 0))
                        .toList(),
                    isCurved: true,
                    color: Colors.red,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _Legend(color: Colors.green, label: 'Income'),
            const SizedBox(width: 16),
            _Legend(color: Colors.red, label: 'Expenses'),
          ]),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label),
      ]);
}
```

> Note: `CurrencyFormatter.compact(int cents)` must be added to `lib/shared/utils/currency_formatter.dart`. It should format large values as e.g. `$1.2k`, `$3.4M`, otherwise fall back to `$X`.

- [ ] **Step 2.3: Implement CategoryChart (pie chart)**

The `PieChartData` must use `sectionsSpace: 2` and `centerSpaceRadius: 40`. Section colors come from the category's `color` hex string (from the API), with a fallback palette. Section titles show percentage; the legend table below shows amounts.

```dart
// apps/mobile/lib/features/reports/charts/category_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/workspaces/workspace_provider.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class CategoryChart extends ConsumerWidget {
  const CategoryChart({super.key});

  static const _fallbackColors = [
    Color(0xFF5B67CA), Color(0xFFE07B54), Color(0xFF4CAF50),
    Color(0xFFFFC107), Color(0xFF9C27B0), Color(0xFF00BCD4),
    Color(0xFFFF5722), Color(0xFF607D8B), Color(0xFF795548),
  ];

  /// Parse a hex color string like "#4CAF50" → Color(0xFF4CAF50).
  /// Falls back to the indexed palette color if parsing fails.
  Color _colorFor(String? hex, int index) {
    if (hex != null && hex.startsWith('#') && hex.length == 7) {
      try {
        return Color(int.parse(hex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return _fallbackColors[index % _fallbackColors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byCategory = ref.watch(reportsNotifierProvider).byCategory;
    final currency = ref.watch(activeWorkspaceProvider)?.currency ?? 'USD';

    if (byCategory.isEmpty) {
      return const Center(child: Text('No expense data for this period'));
    }

    final total = byCategory.fold<int>(0, (sum, c) => sum + c.total);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Expenses by Category', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: PieChart(
              PieChartData(
                sections: byCategory.asMap().entries.map((e) {
                  final i = e.key;
                  final cat = e.value;
                  final pct = total > 0 ? (cat.total / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: cat.total.toDouble(),
                    title: '${pct.toStringAsFixed(1)}%',
                    color: _colorFor(cat.color, i),
                    radius: 80,
                    titleStyle: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...byCategory.asMap().entries.map((e) {
            final i = e.key;
            final cat = e.value;
            return ListTile(
              leading: Container(
                width: 12, height: 12,
                color: _colorFor(cat.color, i),
              ),
              title: Text(cat.categoryName),
              trailing: Text(CurrencyFormatter.format(cat.total, currency)),
              dense: true,
            );
          }),
        ],
      ),
    );
  }
}
```

> Note: `CategorySpend` model (in `reports_provider.dart`) must include a `color` field: `final String? color;` sourced from the joined category row. Update `CategorySpend.fromJson` accordingly.

- [ ] **Step 2.4: Commit**

```bash
git add apps/mobile/lib/features/reports/charts/summary_tab.dart apps/mobile/lib/features/reports/charts/trends_chart.dart apps/mobile/lib/features/reports/charts/category_chart.dart
git commit -m "feat(mobile/reports): add SummaryTab, TrendsChart (line), CategoryChart (pie)"
```

---

## Task 3: Charts — BudgetVsActualChart, YearOverYearChart, HeatmapChart
Depends-on: 1

**Files:**
- Create: `lib/features/reports/charts/budget_vs_actual_chart.dart`
- Create: `lib/features/reports/charts/year_over_year_chart.dart`
- Create: `lib/features/reports/charts/heatmap_chart.dart`

- [ ] **Step 3.1: Implement BudgetVsActualChart (horizontal bar)**

```dart
// apps/mobile/lib/features/reports/charts/budget_vs_actual_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/workspaces/workspace_provider.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class BudgetVsActualChart extends ConsumerWidget {
  const BudgetVsActualChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(reportsNotifierProvider).budgetVsActual;
    final currency = ref.watch(activeWorkspaceProvider)?.currency ?? 'USD';

    if (rows.isEmpty) {
      return const Center(child: Text('No budgets set for this period'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Budget vs Actual', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        ...rows.map((row) {
          final pct = row.budgetAmount > 0
              ? (row.actualAmount / row.budgetAmount).clamp(0.0, 1.0)
              : 0.0;
          final color = pct >= 1.0 ? Colors.red : pct >= 0.8 ? Colors.orange : Colors.green;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.categoryName ?? 'Total Budget'),
                    Text(
                      '${CurrencyFormatter.format(row.actualAmount, currency)} / ${CurrencyFormatter.format(row.budgetAmount, currency)}',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: pct,
                  color: color,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
```

- [ ] **Step 3.2: Implement YearOverYearChart (grouped bar)**

```dart
// apps/mobile/lib/features/reports/charts/year_over_year_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../reports_provider.dart';

class YearOverYearChart extends ConsumerWidget {
  const YearOverYearChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reportsNotifierProvider).yearOverYear;

    if (data.isEmpty) {
      return const Center(child: Text('No year-over-year data available'));
    }

    // Group expense data by month, then by year
    final years = data.map((p) => p.month ~/ 100).toSet().toList()..sort();
    final currentYear = DateTime.now().year;
    final lastYear = currentYear - 1;

    final thisYearExpense = <int, double>{};
    final lastYearExpense = <int, double>{};
    for (final p in data) {
      if (p.type != 'EXPENSE') continue;
      // yearOverYear data has month field from API (1-12) scoped by year via date range
      // We use a simplified approach: split by relative year
      if (p.month > 1200) {
        thisYearExpense[p.month % 100] = p.total / 100.0;
      } else {
        lastYearExpense[p.month % 100] = p.total / 100.0;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Year Over Year Comparison', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                groupsSpace: 12,
                barGroups: List.generate(12, (i) {
                  final m = i + 1;
                  return BarChartGroupData(
                    x: m,
                    barRods: [
                      BarChartRodData(
                        toY: lastYearExpense[m] ?? 0,
                        color: Colors.blue.withOpacity(0.5),
                        width: 8,
                      ),
                      BarChartRodData(
                        toY: thisYearExpense[m] ?? 0,
                        color: Colors.blue,
                        width: 8,
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        DateFormat.MMM().format(DateTime(2026, v.toInt())),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.3: Implement HeatmapChart**

The heatmap is a 365-day calendar grid (52 columns × 7 rows). Color intensity is proportional to spend: 0 spend → theme surface color, max spend → `colorScheme.primary` at full opacity. Each cell shows a `Tooltip` with the date and formatted amount.

```dart
// apps/mobile/lib/features/reports/charts/heatmap_chart.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../features/workspaces/workspace_provider.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../reports_provider.dart';

class HeatmapChart extends ConsumerWidget {
  const HeatmapChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmap = ref.watch(reportsNotifierProvider).heatmap;
    final currency = ref.watch(activeWorkspaceProvider)?.currency ?? 'USD';

    if (heatmap.isEmpty) {
      return const Center(child: Text('No spending data available'));
    }

    // 52 columns (weeks) × 7 rows (days) grid
    // Color intensity: 0 = transparent, max = theme primary with full opacity
    final dataByDay = {for (final d in heatmap) d.day: d.total};
    final maxTotal = heatmap.map((d) => d.total).reduce(math.max);

    final year = DateTime.parse(heatmap.first.day).year;
    final jan1 = DateTime(year, 1, 1);
    final dec31 = DateTime(year, 12, 31);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Spending Heatmap ($year)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Darker = more spending',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: dec31.difference(jan1).inDays + 1,
            itemBuilder: (context, index) {
              final day = jan1.add(Duration(days: index));
              final key = DateFormat('yyyy-MM-dd').format(day);
              final total = dataByDay[key] ?? 0;
              final intensity = maxTotal > 0 ? total / maxTotal : 0.0;
              return Tooltip(
                message: '$key: ${CurrencyFormatter.format(total, currency)}',
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(intensity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.4: Commit**

```bash
git add apps/mobile/lib/features/reports/charts/budget_vs_actual_chart.dart apps/mobile/lib/features/reports/charts/year_over_year_chart.dart apps/mobile/lib/features/reports/charts/heatmap_chart.dart
git commit -m "feat(mobile/reports): add BudgetVsActual, YearOverYear, Heatmap charts"
```

---

## Task 4: ExportButton + ReportsScreen
Depends-on: 2, 3

**Files:**
- Create: `lib/features/reports/export_button.dart`
- Create: `lib/features/reports/reports_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 4.1: Implement ExportButton**

The `ExportButton` appends the JWT access token to the URL so the server can authenticate the streaming download without a request body. It opens the URL via `url_launcher` (browser on web, external app on mobile).

```dart
// apps/mobile/lib/features/reports/export_button.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/secure_storage.dart';
import '../../features/workspaces/workspace_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExportButton extends ConsumerWidget {
  final String workspaceId;
  final String format; // 'csv' or 'pdf'
  const ExportButton({required this.workspaceId, required this.format, super.key});

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final apiBase = const String.fromEnvironment(
        'API_BASE_URL', defaultValue: 'https://api.expensetracker.app');
    final storage = ref.read(secureStorageProvider);
    final token = await storage.getAccessToken();
    final url = '$apiBase/workspaces/$workspaceId/reports/export?format=$format';
    // Open in browser — server streams the file with Content-Disposition: attachment
    await launchUrl(
      Uri.parse('$url&token=$token'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      icon: Icon(format == 'csv' ? Icons.table_chart : Icons.picture_as_pdf),
      label: Text(format.toUpperCase()),
      onPressed: () => _download(context, ref),
    );
  }
}
```

> Note: The ReportsScreen action bar should render both buttons:
> ```dart
> ExportButton(workspaceId: workspace.id, format: 'csv'),
> ExportButton(workspaceId: workspace.id, format: 'pdf'),
> ```

**Test step:** Mock the `url_launcher` package via `url_launcher_platform_interface`. Assert that tapping the CSV button calls `launchUrl` with a URL containing `format=csv`, and the PDF button with `format=pdf`.

- [ ] **Step 4.2: Implement ReportsScreen**

```dart
// apps/mobile/lib/features/reports/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'charts/summary_tab.dart';
import 'charts/trends_chart.dart';
import 'charts/category_chart.dart';
import 'charts/budget_vs_actual_chart.dart';
import 'charts/year_over_year_chart.dart';
import 'charts/heatmap_chart.dart';
import 'export_button.dart';
import 'reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportsNotifierProvider.notifier).fetchReports(
            year: _now.year,
            month: _now.month,
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          ExportButton(year: _now.year, month: _now.month),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(reportsNotifierProvider.notifier)
                .fetchReports(year: _now.year, month: _now.month),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Trends'),
            Tab(text: 'By Category'),
            Tab(text: 'vs Budget'),
            Tab(text: 'Year/Year'),
            Tab(text: 'Heatmap'),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: const [
                SummaryTab(),
                TrendsChart(),
                CategoryChart(),
                BudgetVsActualChart(),
                YearOverYearChart(),
                HeatmapChart(),
              ],
            ),
    );
  }
}
```

- [ ] **Step 4.3: Update GoRouter**

In `lib/core/router/app_router.dart`:
```dart
import '../../features/reports/reports_screen.dart';

GoRoute(path: AppRoutes.reports, builder: (_, __) => const ReportsScreen()),
```

- [ ] **Step 4.4: Run full test suite**

```bash
cd apps/mobile && flutter test
```

Expected: All tests pass.

- [ ] **Step 4.5: Run flutter analyze**

```bash
flutter analyze
```

Expected: No issues.

- [ ] **Step 4.6: Commit**

```bash
git add apps/mobile/lib/features/reports/ apps/mobile/lib/core/router/app_router.dart
git commit -m "feat(mobile/reports): add ReportsScreen with 6-tab FL Chart views and CSV/PDF export"
```

---

## Phase 8 Complete

- ✅ `ReportsNotifier` — parallel fetch of all 6 endpoints, strongly-typed data classes
- ✅ `SummaryTab` — income/expense/net cards
- ✅ `TrendsChart` — `LineChart` with dual income/expense series, month axis
- ✅ `CategoryChart` — `PieChart` with color-coded sections + legend table
- ✅ `BudgetVsActualChart` — progress bars with red/orange/green thresholds
- ✅ `YearOverYearChart` — grouped `BarChart` (last year vs this year)
- ✅ `HeatmapChart` — 365-day color intensity grid with tooltip
- ✅ `ExportButton` — popup menu triggering CSV or PDF download via `url_launcher`
- ✅ `ReportsScreen` — 6-tab `TabBar`, loading state, refresh action
- ✅ Unit test: 1 provider test

**Next plan:** `2026-06-16-flutter-phase9.md` — Notifications (WebSocket client, bell badge, notification list)
