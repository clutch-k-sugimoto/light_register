import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:light_register/data/register_database.dart';
import 'package:light_register/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late RegisterDatabase database;
  late Directory directory;
  late DateTime now;
  const yakisoba = Product(
    id: 'yakisoba',
    name: '焼きそば',
    price: 500,
    category: 'フード',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('light-register-test-');
    now = DateTime(2026, 9, 11, 12);
    database = await RegisterDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      filePath: '${directory.path}/register.db',
      clock: () => now,
    );
    await database.saveProduct(yakisoba);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<Order> add(Product product, {int count = 1}) async {
    final previous = await database.order();
    var next = previous;
    for (var i = 0; i < count; i++) {
      next = next.add(product);
    }
    await database.saveOrder(previous, next);
    return next;
  }

  Future<List<Sale>> allSales() =>
      database.sales(from: DateTime(2026, 1, 1), to: DateTime(2026, 12, 31));

  test('商品と未会計の注文はDBを閉じて再接続しても復元される', () async {
    final order = await add(yakisoba, count: 2);
    await database.close();
    database = await RegisterDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      filePath: '${directory.path}/register.db',
      clock: () => now,
    );
    expect((await database.products()).single.name, '焼きそば');
    final restored = await database.order();
    expect(restored.id, order.id);
    expect(restored.total, 1000);
    expect(restored.quantity, 2);
    expect(await allSales(), isEmpty);
  });

  test('会計は売上保存と注文クリアを一括で行い釣り銭を整数で計算する', () async {
    final order = await add(yakisoba, count: 2);
    final sale = await database.checkout(order, 5000);
    expect(sale.total, 1000);
    expect(sale.received, 5000);
    expect(sale.change, 4000);
    expect((await allSales()).single.id, sale.id);
    expect((await database.order()).lines, isEmpty);
    await database.close();
    database = await RegisterDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      filePath: '${directory.path}/register.db',
    );
    expect((await allSales()).single.change, 4000);
    expect((await database.order()).id, isNot(order.id));
  });

  test('同時確定と通信結果不明時の再試行でも二重計上しない', () async {
    final order = await add(yakisoba);
    final result = await Future.wait([
      database.checkout(order, 1000),
      database.checkout(order, 1000),
    ]);
    expect(result[0].id, result[1].id);
    expect(await allSales(), hasLength(1));
    await add(yakisoba, count: 2);
    await database.checkout(order, 5000);
    expect(await allSales(), hasLength(1));
    expect((await database.order()).total, 1000);
  });

  test('預り不足は売上と注文を変更しない', () async {
    final order = await add(yakisoba);
    await expectLater(
      database.checkout(order, 499),
      throwsA(isA<RegisterException>()),
    );
    expect(await allSales(), isEmpty);
    expect((await database.order()).total, 500);
  });

  test('売上挿入後に注文クリアが失敗すると取引全体をロールバックする', () async {
    final order = await add(yakisoba);
    await database.db.execute(
      '''CREATE TRIGGER fail_draft BEFORE UPDATE ON draft
      BEGIN SELECT RAISE(ABORT, 'simulated disk failure'); END''',
    );
    await expectLater(
      database.checkout(order, 1000),
      throwsA(isA<DatabaseException>()),
    );
    expect(await allSales(), isEmpty);
    expect((await database.order()).id, order.id);
    await database.db.execute('DROP TRIGGER fail_draft');
    await database.checkout(order, 1000);
    expect(await allSales(), hasLength(1));
  });

  test('価格・名称変更と販売終了後も過去の明細は変わらない', () async {
    final first = await add(yakisoba);
    await database.checkout(first, 1000);
    const edited = Product(
      id: 'yakisoba',
      name: '特製焼きそば',
      price: 600,
      category: 'フード',
    );
    await database.saveProduct(edited);
    now = now.add(const Duration(hours: 1));
    await database.checkout(await add(edited, count: 2), 2000);
    await database.archiveProduct(edited.id);
    expect(await database.products(), isEmpty);
    final sales = await allSales();
    expect(sales.last.lines.single.name, '焼きそば');
    expect(sales.last.total, 500);
    final grouped = groupByProduct(sales).single;
    expect(grouped.total, 1700);
    expect(grouped.quantity, 3);
    expect(grouped.name, '特製焼きそば');
  });

  test('同名の別商品を混同せず安定した商品IDで集計する', () async {
    const second = Product(id: 'second', name: '焼きそば', price: 300);
    await database.saveProduct(second);
    await add(yakisoba);
    final order = await add(second);
    await database.checkout(order, 1000);
    expect(groupByProduct(await allSales()), hasLength(2));
  });

  test('日付境界の売上は確定日で集計し指定期間の両端を含む', () async {
    now = DateTime(2026, 9, 10, 23, 59, 59);
    await database.checkout(await add(yakisoba), 500);
    now = DateTime(2026, 9, 11);
    await database.checkout(await add(yakisoba, count: 2), 1000);
    final daily = groupByDate(await allSales());
    expect(daily.map((d) => d.total), [1000, 500]);
    final day = await database.sales(
      from: DateTime(2026, 9, 11),
      to: DateTime(2026, 9, 11),
    );
    expect(day, hasLength(1));
    expect(day.single.total, 1000);
  });

  test('古い注文内容による保存と会計を拒否する', () async {
    final stale = await add(yakisoba);
    final latest = await add(yakisoba);
    await expectLater(
      database.saveOrder(stale, stale.add(yakisoba)),
      throwsA(isA<RegisterException>()),
    );
    await expectLater(
      database.checkout(stale, 5000),
      throwsA(isA<RegisterException>()),
    );
    expect((await database.order()).revision, latest.revision);
    expect(await allSales(), isEmpty);
  });

  test('価格変更をまたぐ未会計の商品は単価別に保持する', () async {
    await add(yakisoba);
    const edited = Product(id: 'yakisoba', name: '焼きそば', price: 600);
    await database.saveProduct(edited);
    final order = await add(edited);
    expect(order.lines, hasLength(2));
    expect(order.total, 1100);
  });

  test('カテゴリ変更前後の明細を個別に数量変更し、再接続・会計後も保持する', () async {
    await add(yakisoba, count: 2);
    const updated = Product(
      id: 'yakisoba',
      name: '焼きそば',
      price: 500,
      category: '麺類',
    );
    await database.saveProduct(updated);
    final order = await add(updated, count: 2);
    expect(order.lines.map((line) => line.category), ['フード', '麺類']);
    expect(order.lines.map((line) => line.quantity), [2, 2]);

    final changed = order
        .changeQuantity(order.lines.first.key, -1)
        .changeQuantity(order.lines.last.key, 1);
    await database.saveOrder(order, changed);
    Future<void> reconnect() async {
      await database.close();
      database = await RegisterDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        filePath: '${directory.path}/register.db',
        clock: () => now,
      );
    }

    await reconnect();
    final restored = await database.order();
    expect(restored.lines.map((line) => line.category), ['フード', '麺類']);
    expect(restored.lines.map((line) => line.quantity), [1, 3]);
    expect(restored.total, 2000);
    await database.checkout(restored, 2000);
    await reconnect();
    final sale = (await allSales()).single;
    expect(sale.lines.map((line) => line.category), ['フード', '麺類']);
    expect(sale.lines.map((line) => line.quantity), [1, 3]);
    expect(sale.total, 2000);
    expect((await database.order()).lines, isEmpty);
  });

  test('商品名とカテゴリに区切り文字があっても異なる明細を混同しない', () async {
    const first = Product(
      id: 'yakisoba',
      name: 'フード:焼きそば',
      price: 500,
      category: '祭',
    );
    const second = Product(
      id: 'yakisoba',
      name: 'フード',
      price: 500,
      category: '焼きそば:祭',
    );
    await database.saveProduct(first);
    await add(first);
    await database.saveProduct(second);
    final order = await add(second);
    final changed = order.changeQuantity(order.lines.last.key, 1);
    await database.saveOrder(order, changed);
    final restored = await database.order();
    expect(restored.lines.map((line) => line.name), ['フード:焼きそば', 'フード']);
    expect(restored.lines.map((line) => line.category), ['祭', '焼きそば:祭']);
    expect(restored.lines.map((line) => line.quantity), [1, 2]);
    expect(restored.total, 1500);
  });

  test('空注文、負数価格、数量上限、金額上限を拒否する', () async {
    await expectLater(
      database.checkout(await database.order(), 0),
      throwsA(isA<RegisterException>()),
    );
    await expectLater(
      database.saveProduct(const Product(id: 'bad', name: '不正', price: -1)),
      throwsA(isA<RegisterException>()),
    );
    final full = Order(
      id: newId(),
      lines: const [
        OrderLine(
          productId: 'yakisoba',
          name: '焼きそば',
          unitPrice: 500,
          quantity: 999,
          category: 'フード',
        ),
      ],
    );
    expect(() => full.add(yakisoba), throwsA(isA<RegisterException>()));
    final order = await add(yakisoba);
    await expectLater(
      database.checkout(order, maxAmount + 1),
      throwsA(isA<RegisterException>()),
    );
  });

  test('0円商品も明示的な0円預りで記録できる', () async {
    const free = Product(id: 'free', name: '無料配布', price: 0);
    await database.saveProduct(free);
    final sale = await database.checkout(await add(free), 0);
    expect(sale.total, 0);
    expect(sale.change, 0);
    expect(sale.quantity, 1);
  });
}
