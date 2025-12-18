import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'transaction_model.dart';

void main() async {
WidgetsFlutterBinding.ensureInitialized();
await DatabaseHelper.instance.initDB();
runApp(const BudgetTrackerApp());
}

class BudgetTrackerApp extends StatelessWidget {
const BudgetTrackerApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
home: const TransactionListScreen(),
);
}
}

class TransactionListScreen extends StatefulWidget {
const TransactionListScreen({super.key});

@override
State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
List<TransactionModel> transactions = [];

@override
void initState() {
super.initState();
loadData();
}

void loadData() async {
transactions = await DatabaseHelper.instance.fetchTransactions();
setState(() {});
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Budget Tracker'),
actions: [
IconButton(
icon: const Icon(Icons.assessment),
onPressed: () => Navigator.push(
context,
MaterialPageRoute(builder: (_) => SummaryScreen(transactions: transactions)),
),
)
],
),

      body: transactions.isEmpty
          ? const Center(child: Text("No transactions yet"))
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return ListTile(
                  title: Text(tx.category),
                  subtitle: Text(tx.date),
                  trailing: Text(
                    (tx.type == "Income" ? "+" : "-") + tx.amount.toStringAsFixed(2),
                    style: TextStyle(color: tx.type == "Income" ? Colors.green : Colors.red),
                  ),
                  onLongPress: () => showOptions(tx),
                );
              }),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
          loadData();
        },
      ),
    );
}

void showOptions(TransactionModel tx) {
showDialog(
context: context,
builder: (_) => AlertDialog(
title: const Text("Modify Transaction"),
actions: [
TextButton(
child: const Text("Delete", style: TextStyle(color: Colors.red)),
onPressed: () async {
await DatabaseHelper.instance.deleteTransaction(tx.id!);
Navigator.pop(context);
loadData();
},
),
TextButton(
child: const Text("Edit"),
onPressed: () async {
Navigator.pop(context);
await Navigator.push(
context,
MaterialPageRoute(builder: (_) => AddTransactionScreen(editTx: tx)),
);
loadData();
},
)
],
),
);
}
}

class AddTransactionScreen extends StatefulWidget {
final TransactionModel? editTx;
const AddTransactionScreen({super.key, this.editTx});

@override
State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
final _formKey = GlobalKey<FormState>();
final categoryController = TextEditingController();
final amountController = TextEditingController();
DateTime? selectedDate;
String type = "Income";

@override
void initState() {
super.initState();
if (widget.editTx != null) {
final tx = widget.editTx!;
categoryController.text = tx.category;
amountController.text = tx.amount.toString();
selectedDate = DateTime.parse(tx.date);
type = tx.type;
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: Text(widget.editTx == null ? "Add Transaction" : "Edit Transaction")),
body: Padding(
padding: const EdgeInsets.all(20.0),
child: Form(
key: _formKey,
child: Column(
children: [
TextFormField(
controller: categoryController,
decoration: const InputDecoration(labelText: "Category"),
validator: (value) => value!.isEmpty ? "Enter category" : null,
),
TextFormField(
controller: amountController,
decoration: const InputDecoration(labelText: "Amount"),
keyboardType: TextInputType.number,
validator: (value) {
if (value!.isEmpty) return "Enter amount";
if (double.tryParse(value) == null) return "Invalid number";
return null;
},
),
const SizedBox(height: 10),

              Row(
                children: [
                  Text(selectedDate == null
                      ? "No Date Selected"
                      : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                  const Spacer(),
                  TextButton(
                    child: const Text("Pick Date"),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  )
                ],
              ),

              DropdownButtonFormField(
                value: type,
                items: ["Income", "Expense"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => type = val!),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                child: Text(widget.editTx == null ? "Add" : "Save"),
                onPressed: () async {
                  if (_formKey.currentState!.validate() && selectedDate != null) {
                    final tx = TransactionModel(
                      id: widget.editTx?.id,
                      category: categoryController.text,
                      amount: double.parse(amountController.text),
                      type: type,
                      date: selectedDate!.toIso8601String().split('T').first,
                    );

                    if (widget.editTx == null) {
                      await DatabaseHelper.instance.addTransaction(tx);
                    } else {
                      await DatabaseHelper.instance.updateTransaction(tx);
                    }

                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
}
}

class SummaryScreen extends StatelessWidget {
final List<TransactionModel> transactions;
const SummaryScreen({super.key, required this.transactions});

@override
Widget build(BuildContext context) {
final income = transactions.where((t) => t.type == "Income").fold(0.0, (s, t) => s + t.amount);
final expense = transactions.where((t) => t.type == "Expense").fold(0.0, (s, t) => s + t.amount);
final balance = income - expense;

    return Scaffold(
      appBar: AppBar(title: const Text("Summary")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Income: ₱${income.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontSize: 18)),
            Text("Expenses: ₱${expense.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontSize: 18)),
            const Divider(height: 30),
            Text(
              "Balance: ₱${balance.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
}
}
