import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/workspaces/workspace_provider.dart';
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
    final workspace = ref.watch(activeWorkspaceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (workspace != null) ...[
            ExportButton(
              workspaceId: workspace.id,
              format: 'csv',
              year: _now.year,
              month: _now.month,
            ),
            ExportButton(
              workspaceId: workspace.id,
              format: 'pdf',
              year: _now.year,
              month: _now.month,
            ),
          ],
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
