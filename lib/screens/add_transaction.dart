import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../transaction_model.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final VoidCallback? onSuccess;

  const AddTransactionScreen({super.key, this.transaction, this.onSuccess});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController categoryController;
  late TextEditingController amountController;
  DateTime selectedDate = DateTime.now();
  String type = "Income";
  bool isSaving = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    categoryController =
        TextEditingController(text: widget.transaction?.category ?? '');
    amountController =
        TextEditingController(text: widget.transaction?.amount.toString() ?? '');
    type = widget.transaction?.type ?? "Income";
    selectedDate = widget.transaction?.date ?? DateTime.now();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    categoryController.dispose();
    amountController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final amount = double.tryParse(amountController.text);
      if (amount == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Invalid amount")));
        setState(() => isSaving = false);
        return;
      }

      final tx = TransactionModel(
        id: widget.transaction?.id,
        category: categoryController.text,
        amount: amount,
        type: type,
        date: selectedDate,
      );

      if (widget.transaction == null) {
        await DatabaseHelper.instance.addTransaction(tx);
      } else {
        await DatabaseHelper.instance.updateTransaction(tx);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.transaction == null
              ? "Transaction added successfully!"
              : "Transaction updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Close dialog and return success
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _clearForm() {
    categoryController.clear();
    amountController.clear();
    setState(() {
      type = "Income";
      selectedDate = DateTime.now();
    });
  }

  Future<void> _deleteTransaction() async {
    if (widget.transaction != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this transaction?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await DatabaseHelper.instance.deleteTransaction(widget.transaction!.id!);

        if (!mounted) return;
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.topRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.transaction == null ? "Add Transaction" : "Edit Transaction",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: categoryController,
                          decoration: const InputDecoration(
                            labelText: "Category",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          validator: (v) => v!.isEmpty ? "Enter category" : null,
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: "Amount",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          validator: (v) {
                            if (v!.isEmpty) return "Enter amount";
                            if (double.tryParse(v) == null) return "Invalid number";
                            if (double.parse(v) <= 0) return "Amount must be greater than 0";
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Date",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(selectedDate),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.calendar_today),
                                label: const Text("Pick Date"),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: const InputDecoration(
                              labelText: "Type",
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.compare_arrows),
                            ),
                            items: ["Income", "Expense"]
                                .map(
                                  (e) => DropdownMenuItem(
                                value: e,
                                child: Row(
                                  children: [
                                    Icon(
                                      e == "Income" ? Icons.arrow_upward : Icons.arrow_downward,
                                      color: e == "Income" ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(e),
                                  ],
                                ),
                              ),
                            )
                                .toList(),
                            onChanged: (val) => setState(() => type = val!),
                          ),
                        ),
                        const SizedBox(height: 30),

                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : _submitTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSaving ? Colors.grey : null,
                            ),
                            child: isSaving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                                : Text(
                              widget.transaction == null
                                  ? "Add Transaction"
                                  : "Update Transaction",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),

                        if (widget.transaction != null) ...[
                          const SizedBox(height: 15),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _deleteTransaction,
                              icon: const Icon(Icons.delete),
                              label: const Text("Delete Transaction"),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}