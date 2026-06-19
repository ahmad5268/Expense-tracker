import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../features/workspaces/workspace_provider.dart';

class CategorySpend {
  final String categoryId;
  final String categoryName;
  final String? color;
  final int total;
  final int count;
  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    this.color,
    required this.total,
    required this.count,
  });

  factory CategorySpend.fromJson(Map<String, dynamic> j) => CategorySpend(
        categoryId: j['categoryId'] as String,
        categoryName: j['categoryName'] as String,
        color: j['color'] as String?,
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

  ReportsState copyWith({bool? isLoading}) => ReportsState(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        net: net,
        byCategory: byCategory,
        trends: trends,
        budgetVsActual: budgetVsActual,
        yearOverYear: yearOverYear,
        heatmap: heatmap,
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
