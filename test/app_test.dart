import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:light_register/data/register_database.dart';
import 'package:light_register/domain/models.dart';
import 'package:light_register/main.dart';
import 'package:light_register/register_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late RegisterDatabase database;
  late RegisterController controller;
  setUp(() async {
    database = await RegisterDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      filePath: inMemoryDatabasePath,
    );
    controller = RegisterController(database);
  });
  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  Future<void> seedSaleAndOrder() async {
    const product = Product(id: 'test', name: '焼きそば', price: 500);
    await controller.load();
    await controller.saveProduct(product);
    await controller.add(product);
    await controller.checkout(1000);
    await controller.add(product);
  }

  testWidgets('スマホで商品登録から釣り銭表示、日別・商品別売上まで操作できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('first-product')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-name')), '焼きそば');
    await tester.enterText(find.byKey(const Key('product-price')), '500');
    await tester.enterText(find.byKey(const Key('product-category')), 'フード');
    await tester.ensureVisible(find.byKey(const Key('save-product')));
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
    final id = controller.products.single.id;
    await tester.tap(find.byKey(Key('product-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('product-$id')));
    await tester.pumpAndSettle();
    expect(controller.order.total, 1000);
    await tester.tap(find.byKey(const Key('open-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkout')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('complete-checkout')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('key-5')));
    await tester.pumpAndSettle();
    expect(find.text('¥995 不足しています'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cash-5000')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('complete-checkout')));
    await tester.tap(find.byKey(const Key('complete-checkout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout-success')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('final-change'))).data,
      '¥4,000',
    );
    await tester.tap(find.byKey(const Key('next-order')));
    await tester.pumpAndSettle();
    expect(controller.order.lines, isEmpty);
    await tester.tap(find.text('売上').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('sales-total'))).data,
      '¥1,000',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('sales-count'))).data,
      '1件',
    );
    await tester.ensureVisible(find.text('商品別'));
    await tester.tap(find.text('商品別'));
    await tester.pumpAndSettle();
    expect(find.text('焼きそば'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('タブレットでは商品と注文を同時に表示し数量変更できる', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const product = Product(id: 'test', name: 'かき氷', price: 350);
    await database.saveProduct(product);
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('今回の注文'), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('かき氷を1点増やす'));
    await tester.pumpAndSettle();
    expect(controller.order.total, 700);
    await tester.tap(find.byTooltip('かき氷を1点減らす'));
    await tester.pumpAndSettle();
    expect(controller.order.total, 350);
    expect(tester.takeException(), isNull);
  });

  testWidgets('売上消去は確認でキャンセルでき、実行時は売上表示だけを即座に更新する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedSaleAndOrder();
    final draft = controller.order;
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('売上').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('sales-total'))).data,
      '¥500',
    );
    await tester.tap(find.byKey(const Key('data-management')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-sales')));
    await tester.pumpAndSettle();
    expect(find.textContaining('全期間の売上・会計明細を消去します。売上画面'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-data-deletion')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(await database.sales(from: now, to: now), hasLength(1));
    await tester.tap(find.byKey(const Key('delete-sales')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-sales')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('data-deletion-result'))).data,
      contains('すべての売上記録を消去しました'),
    );
    expect(controller.order.toMap(), draft.toMap());
    expect(controller.products, hasLength(1));
    await tester.ensureVisible(find.byKey(const Key('close-data-management')));
    await tester.tap(find.byKey(const Key('close-data-management')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('sales-total'))).data,
      '¥0',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('sales-count'))).data,
      '0件',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('全消去の失敗時に画面のデータを維持し、再試行成功後は初期画面に戻る', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedSaleAndOrder();
    final draft = controller.order;
    await database.db.execute(
      '''CREATE TRIGGER fail_reset BEFORE INSERT ON draft
      BEGIN SELECT RAISE(ABORT, 'simulated reset failure'); END''',
    );
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('data-management')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('delete-all-data')));
    await tester.tap(find.byKey(const Key('delete-all-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-data-deletion')));
    await tester.pumpAndSettle();
    expect(controller.order.toMap(), draft.toMap());
    await tester.tap(find.byKey(const Key('delete-all-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-all')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('data-deletion-result'))).data,
      contains('データは変更していません'),
    );
    expect(controller.products, hasLength(1));
    expect(controller.order.toMap(), draft.toMap());
    expect(controller.busy, isFalse);
    await database.db.execute('DROP TRIGGER fail_reset');
    await tester.ensureVisible(find.byKey(const Key('delete-all-data')));
    await tester.tap(find.byKey(const Key('delete-all-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-all')));
    await tester.pumpAndSettle();
    expect(controller.products, isEmpty);
    expect(controller.order.lines, isEmpty);
    expect(controller.order.id, isNot(draft.id));
    await tester.ensureVisible(find.byKey(const Key('close-data-management')));
    await tester.tap(find.byKey(const Key('close-data-management')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first-product')), findsOneWidget);
    await tester.tap(find.text('売上').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('sales-total'))).data,
      '¥0',
    );
    expect(tester.takeException(), isNull);
  });
}
