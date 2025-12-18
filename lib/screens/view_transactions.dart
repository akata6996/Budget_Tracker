import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../transaction_model.dart';
import 'add_transaction.dart';


class ViewTransactionsScreen extends StatefulWidget {
  const ViewTransactionsScreen({super.key});

  @override
  State<ViewTransactionsScreen> createState() => _ViewTransactionsScreenState();
}

class _ViewTransactionsScreenState extends State<ViewTransactionsScreen> with TickerProviderStateMixin {
  List<TransactionModel> transactions = [];
  List<String> categories = [];

  DateTime? startDate;
  DateTime? endDate;
  String? selectedCategory;
  String? selectedType;

  late AnimationController _listAnimationController;
  late List<Animation<double>> _itemAnimations;

  @override
  void initState() {
    super.initState();
    loadData();

    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _itemAnimations = List.generate(
      20, // Assume max 20 items for simplicity
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _listAnimationController,
          curve: Interval(
            index * 0.05,
            1.0,
            curve: Curves.easeOut,
          ),
        ),
      ),
    );

    _listAnimationController.forward();
  }

  Future<void> loadData() async {
    final allTransactions = await DatabaseHelper.instance.fetchTransactions(
      startDate: startDate,
      endDate: endDate,
      category: selectedCategory,
      type: selectedType,
    );

    setState(() {
      transactions = allTransactions;
    });

    final allCategories = await DatabaseHelper.instance.getCategories();
    setState(() {
      categories = allCategories;
    });
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FiltersBottomSheet(
        startDate: startDate,
        endDate: endDate,
        categories: categories,
        selectedCategory: selectedCategory,
        selectedType: selectedType,
        onApply: (start, end, category, type) {
          setState(() {
            startDate = start;
            endDate = end;
            selectedCategory = category;
            selectedType = type;
          });
          loadData();
        },
        onClear: () {
          setState(() {
            startDate = null;
            endDate = null;
            selectedCategory = null;
            selectedType = null;
          });
          loadData();
        },
      ),
    );
  }

  void _editTransaction(TransactionModel transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(transaction: transaction),
      ),
    );

    if (result == true) {
      loadData();
    }
  }

  void _deleteTransaction(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteTransaction(id);
      loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Transactions"),
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
                Icons.filter_list_rounded,
                color: Color(0xFF6366F1),
              ),
              onPressed: _showFilters,
              tooltip: 'Filter',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (startDate != null || endDate != null || selectedCategory != null || selectedType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (startDate != null)
                    Chip(
                      label: Text('From: ${DateFormat('yyyy-MM-dd').format(startDate!)}'),
                      onDeleted: () {
                        setState(() {
                          startDate = null;
                        });
                        loadData();
                      },
                    ),
                  if (endDate != null)
                    Chip(
                      label: Text('To: ${DateFormat('yyyy-MM-dd').format(endDate!)}'),
                      onDeleted: () {
                        setState(() {
                          endDate = null;
                        });
                        loadData();
                      },
                    ),
                  if (selectedCategory != null)
                    Chip(
                      label: Text('Category: $selectedCategory'),
                      onDeleted: () {
                        setState(() {
                          selectedCategory = null;
                        });
                        loadData();
                      },
                    ),
                  if (selectedType != null)
                    Chip(
                      label: Text('Type: $selectedType'),
                      onDeleted: () {
                        setState(() {
                          selectedType = null;
                        });
                        loadData();
                      },
                    ),
                ],
              ),
            ),

          Expanded(
            child: transactions.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No transactions found",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    "Try adjusting your filters",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return AnimatedBuilder(
                  animation: _itemAnimations[index % _itemAnimations.length],
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, (1 - _itemAnimations[index % _itemAnimations.length].value) * 50),
                      child: Opacity(
                        opacity: _itemAnimations[index % _itemAnimations.length].value,
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: tx.type == "Income"
                                    ? [const Color(0xFFE8F5E8), const Color(0xFFF1F8E9)]
                                    : [const Color(0xFFFFEBEE), const Color(0xFFFCE4EC)],
                              ),
                            ),
                            child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: tx.type == "Income"
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              child: Icon(
                                tx.type == "Income"
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: tx.type == "Income"
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            title: Text(
                              tx.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('MMM dd, yyyy').format(tx.date),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${tx.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: tx.type == "Income"
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                Text(
                                  tx.type,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tx.type == "Income"
                                        ? Colors.green
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _editTransaction(tx),
                            onLongPress: () => _deleteTransaction(tx.id!),
                          ),
                        ),
                      ),
                    ));
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => const AddTransactionScreen(),
          );

          if (result == true) {
            loadData();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class FiltersBottomSheet extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> categories;
  final String? selectedCategory;
  final String? selectedType;
  final Function(DateTime?, DateTime?, String?, String?) onApply;
  final VoidCallback onClear;

  const FiltersBottomSheet({
    super.key,
    this.startDate,
    this.endDate,
    required this.categories,
    this.selectedCategory,
    this.selectedType,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<FiltersBottomSheet> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _selectedCategory;
  late String? _selectedType;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _selectedCategory = widget.selectedCategory;
    _selectedType = widget.selectedType;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Filter Transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _selectedType == null,
                onSelected: (selected) {
                  setState(() => _selectedType = null);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Income'),
                selected: _selectedType == 'Income',
                selectedColor: Colors.green[100],
                onSelected: (selected) {
                  setState(() => _selectedType = 'Income');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Expense'),
                selected: _selectedType == 'Expense',
                selectedColor: Colors.red[100],
                onSelected: (selected) {
                  setState(() => _selectedType = 'Expense');
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,  // FIXED THIS LINE
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
              ...widget.categories.map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              )),
            ],
            onChanged: (value) {
              setState(() => _selectedCategory = value);
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => _startDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _startDate == null
                        ? 'Start Date'
                        : DateFormat('yyyy-MM-dd').format(_startDate!),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => _endDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _endDate == null
                        ? 'End Date'
                        : DateFormat('yyyy-MM-dd').format(_endDate!),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_startDate, _endDate, _selectedCategory, _selectedType);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}