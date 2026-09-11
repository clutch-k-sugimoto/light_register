import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

class RegisterDatabase {
  RegisterDatabase(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final Database db;
  final DateTime Function() clock;

  static Future<RegisterDatabase> open({
    DatabaseFactory? factory,
    String? filePath,
    DateTime Function()? clock,
  }) async {
    final databaseFactory = factory ?? databaseFactorySqflitePlugin;
    final databasePath =
        filePath ?? path.join(await getDatabasesPath(), 'light_register.db');
    final db = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE products (
          id TEXT PRIMARY KEY, name TEXT NOT NULL,
          price INTEGER NOT NULL CHECK(price BETWEEN 0 AND 999999),
          category TEXT NOT NULL, color INTEGER NOT NULL,
          active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
          created_at TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE sales (
          id TEXT PRIMARY KEY, created_at TEXT NOT NULL,
          business_date TEXT NOT NULL, utc_offset_minutes INTEGER NOT NULL,
          lines_json TEXT NOT NULL, received INTEGER NOT NULL,
          total INTEGER NOT NULL CHECK(total >= 0),
          change_amount INTEGER NOT NULL CHECK(change_amount >= 0),
          CHECK(received = total + change_amount))''');
          await db.execute(
            'CREATE INDEX sales_date ON sales(business_date, created_at)',
          );
          await db.execute(
            'CREATE TABLE draft (singleton INTEGER PRIMARY KEY CHECK(singleton = 1), order_json TEXT NOT NULL)',
          );
          await db.insert('draft', {
            'singleton': 1,
            'order_json': jsonEncode(Order.empty().toMap()),
          });
        },
      ),
    );
    return RegisterDatabase(db, clock: clock);
  }

  Future<List<Product>> products() async => (await db.query(
    'products',
    where: 'active = 1',
    orderBy: 'created_at, id',
  )).map(Product.fromMap).toList();

  Future<void> saveProduct(Product product) async {
    product.validate();
    await db.transaction((txn) async {
      final existing = await txn.query(
        'products',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [product.id],
      );
      if (existing.isEmpty) {
        await txn.insert('products', {
          ...product.toMap(),
          'created_at': clock().toIso8601String(),
        });
      } else {
        await txn.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }
    });
  }

  Future<void> archiveProduct(String id) async {
    await db.update(
      'products',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Order> order() async => _readOrder(db);
  Future<Order> _readOrder(DatabaseExecutor executor) async {
    final row = (await executor.query('draft', where: 'singleton = 1')).single;
    return Order.fromJson(row['order_json'] as String);
  }

  Future<void> saveOrder(Order previous, Order next) async {
    next.validate();
    await db.transaction((txn) async {
      final stored = await _readOrder(txn);
      if (stored.id != previous.id || stored.revision != previous.revision) {
        throw const RegisterException('注文が更新されました。画面を開き直してください。');
      }
      await txn.update('draft', {
        'order_json': jsonEncode(next.toMap()),
      }, where: 'singleton = 1');
    });
  }

  Future<Sale> checkout(Order order, int received) async {
    return db.transaction((txn) async {
      // The order ID is the idempotency key. Retrying a committed order cannot
      // create another sale, even if the previous response was interrupted.
      final existing = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [order.id],
      );
      if (existing.isNotEmpty) return Sale.fromMap(existing.single);
      final stored = await _readOrder(txn);
      if (stored.id != order.id || stored.revision != order.revision) {
        throw const RegisterException('注文内容が変わりました。会計を開き直してください。');
      }
      final sale = Sale.checkout(stored, received, clock());
      await txn.insert('sales', sale.toMap());
      await txn.update('draft', {
        'order_json': jsonEncode(Order.empty().toMap()),
      }, where: 'singleton = 1');
      return sale;
    });
  }

  Future<List<Sale>> sales({
    required DateTime from,
    required DateTime to,
  }) async {
    return (await db.query(
      'sales',
      where: 'business_date >= ? AND business_date <= ?',
      whereArgs: [dayKey(from), dayKey(to)],
      orderBy: 'created_at DESC, id',
    )).map(Sale.fromMap).toList();
  }

  /// Deletes all sale history, independently of the report's date filter.
  /// Products (including archived products) and the current order are retained.
  Future<void> clearSales() => db.transaction((txn) async {
    await txn.delete('sales');
  });

  /// Resets every application record atomically without closing the database.
  /// A new order ID invalidates any pre-reset order still held by a caller.
  Future<Order> clearAllData() => db.transaction((txn) async {
    final emptyOrder = Order.empty();
    await txn.delete('sales');
    await txn.delete('products');
    await txn.delete('draft');
    await txn.insert('draft', {
      'singleton': 1,
      'order_json': jsonEncode(emptyOrder.toMap()),
    });
    return emptyOrder;
  });

  Future<void> close() => db.close();
}
