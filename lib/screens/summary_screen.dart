import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../db_helper.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> with TickerProviderStateMixin {
  double totalIncome = 0;
  double totalExpense = 0;
  double balance = 0;

  Map<String, double> incomeByCategory = {};
  Map<String, double> expenseByCategory = {};

  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = true;
  bool _showIncomeChart = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<Color> _pieChartColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.brown,
    Colors.lightBlue,
    Colors.lightGreen,
    Colors.deepOrange,
    Colors.deepPurple,
  ];

  @override
  void initState() {
    super.initState();
    loadData();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    try {
      totalIncome = await DatabaseHelper.instance.getTotalIncome();
      totalExpense = await DatabaseHelper.instance.getTotalExpense();
      balance = totalIncome - totalExpense;

      incomeByCategory = await DatabaseHelper.instance.getIncomeByCategory();
      expenseByCategory = await DatabaseHelper.instance.getExpenseByCategory();
    } catch (e) {
      debugPrint('Error loading summary data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadDataWithDateRange() async {
    setState(() => isLoading = true);

    try {
      totalIncome = await DatabaseHelper.instance.getTotalByType(
        'Income',
        startDate: startDate,
        endDate: endDate,
      );

      totalExpense = await DatabaseHelper.instance.getTotalByType(
        'Expense',
        startDate: startDate,
        endDate: endDate,
      );

      balance = totalIncome - totalExpense;

      incomeByCategory = await DatabaseHelper.instance.getCategorySummary(
        'Income',
        startDate: startDate,
        endDate: endDate,
      );

      expenseByCategory = await DatabaseHelper.instance.getCategorySummary(
        'Expense',
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Error loading filtered data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<PieChartSectionData> _getPieChartData(Map<String, double> data) {
    final total = data.values.fold(0.0, (sum, value) => sum + value);

    return data.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final amount = entry.value.value;
      final percentage = total > 0 ? (amount / total * 100) : 0;

      return PieChartSectionData(
        color: _pieChartColors[index % _pieChartColors.length],
        value: amount,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildPieChart(Map<String, double> data, String title, Color titleColor) {
    if (data.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: titleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  size: 60,
                  color: titleColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "No $title data yet",
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Add some transactions to see insights",
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = data.values.fold(0.0, (sum, value) => sum + value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                Chip(
                  label: Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  backgroundColor: Color.alphaBlend(
                      titleColor.withOpacity(0.1),
                      Colors.white
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: _getPieChartData(data),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: SingleChildScrollView(
                        child: Column(
                          children: data.entries.toList().asMap().entries.map((entry) {
                            final index = entry.key;
                            final category = entry.value.key;
                            final amount = entry.value.value;
                            final percentage = total > 0 ? (amount / total * 100) : 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _pieChartColors[index % _pieChartColors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${percentage.toStringAsFixed(1)}% of total',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '\$${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('This Month'),
              onTap: () {
                Navigator.pop(context, 'this_month');
              },
            ),
            ListTile(
              title: const Text('Last Month'),
              onTap: () {
                Navigator.pop(context, 'last_month');
              },
            ),
            ListTile(
              title: const Text('This Year'),
              onTap: () {
                Navigator.pop(context, 'this_year');
              },
            ),
            ListTile(
              title: const Text('All Time'),
              onTap: () {
                Navigator.pop(context, 'all_time');
              },
            ),
            ListTile(
              title: const Text('Custom Range'),
              onTap: () {
                Navigator.pop(context, 'custom');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    switch (result) {
      case 'this_month':
        setState(() {
          startDate = firstDayOfMonth;
          endDate = lastDayOfMonth;
        });
        loadDataWithDateRange();
        break;
      case 'last_month':
        setState(() {
          startDate = DateTime(now.year, now.month - 1, 1);
          endDate = DateTime(now.year, now.month, 0);
        });
        loadDataWithDateRange();
        break;
      case 'this_year':
        setState(() {
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, 12, 31);
        });
        loadDataWithDateRange();
        break;
      case 'all_time':
        setState(() {
          startDate = null;
          endDate = null;
        });
        loadData();
        break;
      case 'custom':
        _pickCustomDateRange();
        break;
    }
  }

  Future<void> _pickCustomDateRange() async {
    final initialStartDate = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final initialEndDate = endDate ?? DateTime.now();

    final pickedStart = await showDatePicker(
      context: context,
      initialDate: initialStartDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedStart != null && mounted) {
      final pickedEnd = await showDatePicker(
        context: context,
        initialDate: initialEndDate.isAfter(pickedStart) ? initialEndDate : pickedStart.add(const Duration(days: 30)),
        firstDate: pickedStart,
        lastDate: DateTime(2100),
      );

      if (pickedEnd != null && mounted) {
        setState(() {
          startDate = pickedStart;
          endDate = pickedEnd;
        });
        loadDataWithDateRange();
      }
    }
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: balance >= 0
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (balance >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Balance",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (startDate != null || endDate != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.clear, size: 20, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          startDate = null;
                          endDate = null;
                        });
                        loadData();
                      },
                      tooltip: 'Clear filters',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "\$${balance.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      "Income",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "\$${totalIncome.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.white30,
                ),
                Column(
                  children: [
                    const Text(
                      "Expense",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "\$${totalExpense.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (startDate != null || endDate != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Showing data from ${startDate != null ? DateFormat('MMM dd, yyyy').format(startDate!) : 'Start'} to ${endDate != null ? DateFormat('MMM dd, yyyy').format(endDate!) : 'End'}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Summary"),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.calendar_today_rounded,
                color: Color(0xFF6366F1),
              ),
              onPressed: _showDateRangePicker,
              tooltip: 'Select Date Range',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF10B981),
              ),
              onPressed: () {
                if (startDate == null && endDate == null) {
                  loadData();
                } else {
                  loadDataWithDateRange();
                }
              },
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : RefreshIndicator(
          onRefresh: () async {
            if (startDate == null && endDate == null) {
              await loadData();
            } else {
              await loadDataWithDateRange();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBalanceCard(),

                    const SizedBox(height: 20),

                    // Chart Toggle Buttons
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Income Chart Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _showIncomeChart = true);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: _showIncomeChart ? const Color(0xFF10B981) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.trending_up_rounded,
                                      color: _showIncomeChart ? Colors.white : const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Income',
                                      style: TextStyle(
                                        color: _showIncomeChart ? Colors.white : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Expense Chart Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _showIncomeChart = false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: !_showIncomeChart ? const Color(0xFFEF4444) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.trending_down_rounded,
                                      color: !_showIncomeChart ? Colors.white : const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Expense',
                                      style: TextStyle(
                                        color: !_showIncomeChart ? Colors.white : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Show selected chart
                    if (_showIncomeChart)
                      _buildPieChart(incomeByCategory, "Income Breakdown", Colors.green),
                    if (!_showIncomeChart)
                      _buildPieChart(expenseByCategory, "Expense Breakdown", Colors.red),

                    const SizedBox(height: 20),

                    // Statistics Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.analytics_rounded,
                                    color: Color(0xFF6366F1),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Statistics",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildStatItem(
                              "Savings Rate",
                              totalIncome > 0
                                  ? "${((balance / totalIncome) * 100).toStringAsFixed(1)}%"
                                  : "0%",
                              Icons.savings_rounded,
                              totalIncome > 0 && balance > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 16),
                            _buildStatItem(
                              "Expense/Income Ratio",
                              totalIncome > 0
                                  ? "${((totalExpense / totalIncome) * 100).toStringAsFixed(1)}%"
                                  : "0%",
                              Icons.balance_rounded,
                              const Color(0xFF3B82F6),
                            ),
                            const SizedBox(height: 16),
                            _buildStatItem(
                              "Total Categories",
                              "${incomeByCategory.keys.length + expenseByCategory.keys.length}",
                              Icons.category_rounded,
                              const Color(0xFF8B5CF6),
                            ),
                            const SizedBox(height: 16),
                            _buildStatItem(
                              "Average Income",
                              incomeByCategory.isNotEmpty
                                  ? "\$${(totalIncome / incomeByCategory.length).toStringAsFixed(2)}"
                                  : "\$0.00",
                              Icons.trending_up_rounded,
                              const Color(0xFF10B981),
                            ),
                            const SizedBox(height: 16),
                            _buildStatItem(
                              "Average Expense",
                              expenseByCategory.isNotEmpty
                                  ? "\$${(totalExpense / expenseByCategory.length).toStringAsFixed(2)}"
                                  : "\$0.00",
                              Icons.trending_down_rounded,
                              const Color(0xFFEF4444),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
