import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:light_register/data/register_database.dart';
import 'package:light_register/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late RegisterDatabase database;
  late Order draft;
  late Order completedOrder;
  const product = Product(id: 'active', name: '焼きそば', price: 500);
  const archived = Product(id: 'archived', name: '販売終了商品', price: 200);

  Future<List<Sale>> allSales() =>
      database.sales(from: DateTime(2000), to: DateTime(2100, 12, 31));

  Future<void> reopen() async {
    await database.close();
    database = await RegisterDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      filePath: '${directory.path}/register.db',
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'register-deletion-test-',
    );
    var now = DateTime(2026, 9, 10);
    database = await RegisterDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      filePath: '${directory.path}/register.db',
      clock: () => now,
    );
    await database.saveProduct(product);
    await database.saveProduct(archived);
    final empty = await database.order();
    completedOrder = empty.add(product);
    await database.saveOrder(empty, completedOrder);
    await database.checkout(completedOrder, 1000);
    now = DateTime(2026, 9, 11);
    final nextEmpty = await database.order();
    final nextSale = nextEmpty.add(archived);
    await database.saveOrder(nextEmpty, nextSale);
    await database.checkout(nextSale, 1000);
    await database.archiveProduct(archived.id);
    final currentEmpty = await database.order();
    draft = currentEmpty.add(product).add(product);
    await database.saveOrder(currentEmpty, draft);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('売上消去は全日付を対象とし商品・販売終了商品・未会計注文を保持する', () async {
    await database.clearSales();
    await reopen();
    expect(await allSales(), isEmpty);
    expect(groupByDate(await allSales()), isEmpty);
    expect(groupByProduct(await allSales()), isEmpty);
    expect((await database.products()).single.id, product.id);
    expect(await database.db.query('products'), hasLength(2));
    expect((await database.order()).toMap(), draft.toMap());
    // A delayed retry of a deleted historical sale must not resurrect it.
    await expectLater(
      database.checkout(completedOrder, 1000),
      throwsA(isA<RegisterException>()),
    );
    final sale = await database.checkout(await database.order(), 2000);
    expect(sale.total, 1000);
    expect(await allSales(), hasLength(1));
  });

  test('全消去は販売終了商品を含む全記録を消し再接続後に通常会計を再開できる', () async {
    final empty = await database.clearAllData();
    expect(empty.lines, isEmpty);
    expect(empty.id, isNot(draft.id));
    await reopen();
    expect(await database.db.query('products'), isEmpty);
    expect(await allSales(), isEmpty);
    expect((await database.order()).toMap(), empty.toMap());
    expect(await database.db.query('draft'), hasLength(1));
    await expectLater(
      database.saveOrder(draft, draft.add(product)),
      throwsA(isA<RegisterException>()),
    );
    await expectLater(
      database.checkout(draft, 2000),
      throwsA(isA<RegisterException>()),
    );
    await database.saveProduct(product);
    final order = empty.add(product);
    await database.saveOrder(empty, order);
    expect((await database.checkout(order, 1000)).change, 500);
  });

  test('売上削除途中で失敗した場合は全売上と商品・注文が維持される', () async {
    await database.db.execute(
      '''CREATE TRIGGER fail_sales BEFORE DELETE ON sales
      WHEN OLD.business_date = '2026-09-11'
      BEGIN SELECT RAISE(ABORT, 'simulated delete failure'); END''',
    );
    await expectLater(database.clearSales(), throwsA(isA<DatabaseException>()));
    await reopen();
    expect(await allSales(), hasLength(2));
    expect(await database.db.query('products'), hasLength(2));
    expect((await database.order()).toMap(), draft.toMap());
    await database.db.execute('DROP TRIGGER fail_sales');
    await database.clearSales();
    expect(await allSales(), isEmpty);
  });

  test('全消去の最後の初期化が失敗しても削除済みの商品・売上・注文をすべて復元する', () async {
    await database.db.execute(
      '''CREATE TRIGGER fail_reset BEFORE INSERT ON draft
      BEGIN SELECT RAISE(ABORT, 'simulated reset failure'); END''',
    );
    await expectLater(
      database.clearAllData(),
      throwsA(isA<DatabaseException>()),
    );
    await reopen();
    expect(await allSales(), hasLength(2));
    expect(await database.db.query('products'), hasLength(2));
    expect((await database.order()).toMap(), draft.toMap());
    await database.db.execute('DROP TRIGGER fail_reset');
    await database.clearAllData();
    expect(await database.db.query('products'), isEmpty);
    expect(await allSales(), isEmpty);
    expect((await database.order()).lines, isEmpty);
  });
}
