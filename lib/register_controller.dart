import 'package:flutter/foundation.dart';

import 'data/register_database.dart';
import 'domain/models.dart';

class RegisterController extends ChangeNotifier {
  RegisterController(this.database);
  final RegisterDatabase database;
  List<Product> products = [];
  Order order = Order.empty();
  bool busy = false;
  bool loaded = false;

  Future<void> load() async {
    final nextProducts = await database.products();
    final nextOrder = await database.order();
    products = nextProducts;
    order = nextOrder;
    loaded = true;
    notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    if (busy) throw const RegisterException('保存中です。少しお待ちください。');
    busy = true;
    notifyListeners();
    try {
      return await operation();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> saveProduct(Product product) => _run(() async {
    await database.saveProduct(product);
    products = await database.products();
  });
  Future<void> archiveProduct(String id) => _run(() async {
    await database.archiveProduct(id);
    products = await database.products();
  });
  Future<void> add(Product product) => _run(() async {
    final next = order.add(product);
    await database.saveOrder(order, next);
    order = next;
  });
  Future<void> changeQuantity(String key, int delta) => _run(() async {
    final next = order.changeQuantity(key, delta);
    await database.saveOrder(order, next);
    order = next;
  });
  Future<void> clearOrder() => _run(() async {
    final next = Order.empty();
    await database.saveOrder(order, next);
    order = next;
  });
  Future<void> clearSales() => _run(database.clearSales);
  Future<void> clearAllData() => _run(() async {
    final emptyOrder = await database.clearAllData();
    // Update visible state only after the entire transaction commits.
    products = [];
    order = emptyOrder;
    loaded = true;
  });
  Future<Sale> checkout(int received) => _run(() async {
    final sale = await database.checkout(order, received);
    // Keep the committed sale result available even if a subsequent read fails.
    // A later write using a new draft is verified against the stored revision.
    try {
      order = await database.order();
    } catch (_) {
      loaded = false;
    }
    return sale;
  });
}
