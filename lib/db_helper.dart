import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('transactions.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<int> addTransaction(TransactionModel tx) async {
    final db = await database;
    return await db.insert('transactions', tx.toMap());
  }

  Future<List<TransactionModel>> fetchTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? type,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    List<Object?> whereArgs = [];

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      // Use start of day
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      whereArgs.add(startOfDay.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      // Use end of day (23:59:59.999)
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
      whereArgs.add(endOfDay.toIso8601String());
    }

    if (category != null && category.isNotEmpty) {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }

    if (type != null && type.isNotEmpty) {
      whereClause += ' AND type = ?';
      whereArgs.add(type);
    }

    final maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );

    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      distinct: true,
      columns: ['category'],
    );
    return maps.map((m) => m['category'] as String).toList();
  }

  // Updated method with optional date parameters
  Future<Map<String, double>> getCategorySummary(
      String type, {
        DateTime? startDate,
        DateTime? endDate,
      }) async {
    final db = await database;

    String whereClause = 'type = ?';
    List<Object?> whereArgs = [type];

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final maps = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE $whereClause
      GROUP BY category
    ''', whereArgs);

    final result = <String, double>{};
    for (var map in maps) {
      result[map['category'] as String] = map['total'] as double;
    }

    return result;
  }

  Future<int> updateTransaction(TransactionModel tx) async {
    final db = await database;
    return await db.update(
      'transactions',
      tx.toMap(),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Updated method with optional date parameters
  Future<double> getTotalByType(
      String type, {
        DateTime? startDate,
        DateTime? endDate,
      }) async {
    final db = await database;

    String whereClause = 'type = ?';
    List<Object?> whereArgs = [type];

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE $whereClause',
      whereArgs,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Helper method for summary screen (simpler version)
  Future<double> getTotalIncome() async {
    return await getTotalByType('Income');
  }

  Future<double> getTotalExpense() async {
    return await getTotalByType('Expense');
  }

  Future<Map<String, double>> getIncomeByCategory() async {
    return await getCategorySummary('Income');
  }

  Future<Map<String, double>> getExpenseByCategory() async {
    return await getCategorySummary('Expense');
  }
}