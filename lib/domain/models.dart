import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const maxPrice = 999999;
const maxAmount = 999999999;
const maxQuantity = 999;
const productColors = [
  0xFFF4AF45,
  0xFF60B7B0,
  0xFFEC8671,
  0xFF829BC8,
  0xFFAF90BE,
];
final _yenFormat = NumberFormat.decimalPattern('ja_JP');
String yen(int value) => '¥${_yenFormat.format(value)}';
String dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
String newId() => const Uuid().v4();

class RegisterException implements Exception {
  const RegisterException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.category = '',
    this.color = 0,
    this.active = true,
  });
  final String id;
  final String name;
  final int price;
  final String category;
  final int color;
  final bool active;

  void validate() {
    if (name.trim().isEmpty || name.length > 40) {
      throw const RegisterException('商品名は1〜40文字で入力してください。');
    }
    if (price < 0 || price > maxPrice) {
      throw const RegisterException('販売価格は0〜999,999円で入力してください。');
    }
    if (category.length > 20 || color < 0 || color >= productColors.length) {
      throw const RegisterException('商品の分類または色が不正です。');
    }
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'color': color,
    'active': active ? 1 : 0,
  };
  factory Product.fromMap(Map<String, Object?> row) => Product(
    id: row['id'] as String,
    name: row['name'] as String,
    price: row['price'] as int,
    category: row['category'] as String,
    color: row['color'] as int,
    active: row['active'] == 1,
  );
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.category,
  });
  final String productId;
  final String name;
  final int unitPrice;
  final int quantity;
  final String category;
  int get total => unitPrice * quantity;
  // Keep different snapshots separate, even when names contain delimiters.
  String get key => jsonEncode([productId, unitPrice, name, category]);
  OrderLine withQuantity(int value) => OrderLine(
    productId: productId,
    name: name,
    unitPrice: unitPrice,
    quantity: value,
    category: category,
  );
  Map<String, Object?> toMap() => {
    'productId': productId,
    'name': name,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'category': category,
  };
  factory OrderLine.fromMap(Map<String, dynamic> row) => OrderLine(
    productId: row['productId'] as String,
    name: row['name'] as String,
    unitPrice: row['unitPrice'] as int,
    quantity: row['quantity'] as int,
    category: row['category'] as String,
  );
}

class Order {
  Order({required this.id, required List<OrderLine> lines, this.revision = 0})
    : lines = List.unmodifiable(lines);
  factory Order.empty() => Order(id: newId(), lines: const []);
  final String id;
  final List<OrderLine> lines;
  final int revision;
  int get total => lines.fold(0, (value, line) => value + line.total);
  int get quantity => lines.fold(0, (value, line) => value + line.quantity);

  void validate() {
    if (lines.any(
      (line) =>
          line.quantity < 1 ||
          line.quantity > maxQuantity ||
          line.unitPrice < 0 ||
          line.unitPrice > maxPrice,
    )) {
      throw const RegisterException('数量は1〜999個で指定してください。');
    }
    if (total > maxAmount) throw const RegisterException('会計金額が上限を超えています。');
  }

  Order add(Product product) {
    product.validate();
    if (!product.active) throw const RegisterException('販売を終了した商品です。');
    final candidate = OrderLine(
      productId: product.id,
      name: product.name,
      unitPrice: product.price,
      quantity: 1,
      category: product.category,
    );
    final index = lines.indexWhere((line) => line.key == candidate.key);
    final next = [...lines];
    if (index == -1) {
      next.add(candidate);
    } else {
      next[index] = next[index].withQuantity(next[index].quantity + 1);
    }
    final order = Order(id: id, lines: next, revision: revision + 1);
    order.validate();
    return order;
  }

  Order changeQuantity(String key, int change) {
    final next = lines
        .map(
          (line) => line.key == key
              ? line.withQuantity(line.quantity + change)
              : line,
        )
        .where((line) => line.quantity > 0)
        .toList();
    final order = Order(id: id, lines: next, revision: revision + 1);
    order.validate();
    return order;
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'revision': revision,
    'lines': lines.map((line) => line.toMap()).toList(),
  };
  factory Order.fromJson(String json) {
    final row = jsonDecode(json) as Map<String, dynamic>;
    return Order(
      id: row['id'] as String,
      revision: row['revision'] as int,
      lines: (row['lines'] as List)
          .map((line) => OrderLine.fromMap(line as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Sale {
  Sale({
    required this.id,
    required this.createdAt,
    required this.businessDate,
    required this.utcOffsetMinutes,
    required List<OrderLine> lines,
    required this.received,
    required this.total,
    required this.change,
  }) : lines = List.unmodifiable(lines);
  final String id;
  final String createdAt;
  final String businessDate;
  final int utcOffsetMinutes;
  final List<OrderLine> lines;
  final int received;
  final int total;
  final int change;
  int get quantity => lines.fold(0, (value, line) => value + line.quantity);
  String get timeLabel => createdAt.substring(11, 16);
  String get receiptLabel => id.substring(0, 8).toUpperCase();

  factory Sale.checkout(Order order, int received, DateTime now) {
    order.validate();
    if (order.lines.isEmpty) throw const RegisterException('商品を追加してください。');
    if (received < order.total) throw const RegisterException('お預り金額が不足しています。');
    if (received > maxAmount) throw const RegisterException('お預り金額が上限を超えています。');
    return Sale(
      id: order.id,
      createdAt: now.toIso8601String(),
      businessDate: dayKey(now),
      utcOffsetMinutes: now.timeZoneOffset.inMinutes,
      lines: order.lines,
      received: received,
      total: order.total,
      change: received - order.total,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'created_at': createdAt,
    'business_date': businessDate,
    'utc_offset_minutes': utcOffsetMinutes,
    'lines_json': jsonEncode(lines.map((line) => line.toMap()).toList()),
    'received': received,
    'total': total,
    'change_amount': change,
  };
  factory Sale.fromMap(Map<String, Object?> row) => Sale(
    id: row['id'] as String,
    createdAt: row['created_at'] as String,
    businessDate: row['business_date'] as String,
    utcOffsetMinutes: row['utc_offset_minutes'] as int,
    lines: (jsonDecode(row['lines_json'] as String) as List)
        .map((line) => OrderLine.fromMap(line as Map<String, dynamic>))
        .toList(),
    received: row['received'] as int,
    total: row['total'] as int,
    change: row['change_amount'] as int,
  );
}

class DailySales {
  const DailySales(this.date, this.total, this.transactions, this.quantity);
  final String date;
  final int total;
  final int transactions;
  final int quantity;
}

class ProductSales {
  const ProductSales(this.id, this.name, this.quantity, this.total);
  final String id;
  final String name;
  final int quantity;
  final int total;
}

List<DailySales> groupByDate(List<Sale> sales) {
  final groups = <String, List<Sale>>{};
  for (final sale in sales) {
    (groups[sale.businessDate] ??= []).add(sale);
  }
  return groups.entries
      .map(
        (entry) => DailySales(
          entry.key,
          entry.value.fold(0, (n, sale) => n + sale.total),
          entry.value.length,
          entry.value.fold(0, (n, sale) => n + sale.quantity),
        ),
      )
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

List<ProductSales> groupByProduct(List<Sale> sales) {
  final groups = <String, ProductSales>{};
  // Aggregate by permanent ID, using the most recent sale-time name.
  final sorted = [...sales]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  for (final sale in sorted) {
    for (final line in sale.lines) {
      final previous = groups[line.productId];
      groups[line.productId] = ProductSales(
        line.productId,
        line.name,
        (previous?.quantity ?? 0) + line.quantity,
        (previous?.total ?? 0) + line.total,
      );
    }
  }
  return groups.values.toList()..sort((a, b) {
    final byTotal = b.total.compareTo(a.total);
    return byTotal == 0 ? a.name.compareTo(b.name) : byTotal;
  });
}
