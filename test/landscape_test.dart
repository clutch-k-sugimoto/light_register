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
    for (var i = 0; i < 12; i++) {
      await database.saveProduct(
        Product(
          id: 'product-$i',
          name: '商品${i.toString().padLeft(2, '0')}',
          price: 500,
        ),
      );
    }
  });
  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  testWidgets('注文表示中に回転しても注文と検索を保持し、安全領域・文字拡大下で数量変更できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-search')), '商品00');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product-product-0')));
    await tester.pumpAndSettle();
    final orderId = controller.order.id;
    await tester.tap(find.byKey(const Key('open-order')));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(844, 390);
    tester.view.padding = const FakeViewPadding(
      left: 44,
      right: 44,
      bottom: 21,
    );
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('商品00を1点増やす'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('商品00を1点増やす').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('商品00を1点増やす'));
    await tester.pumpAndSettle();
    expect(controller.order.quantity, 2);
    expect(controller.order.id, orderId);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('checkout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('注文に戻る'));
    await tester.pumpAndSettle();
    expect(controller.order.id, orderId);
    expect(controller.order.total, 1000);
    final search = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('product-search')),
        matching: find.byType(EditableText),
      ),
    );
    expect(search.controller.text, '商品00');
    expect(find.byKey(const Key('product-product-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('商品管理は横画面で末尾の商品を編集し、キーボード表示中も保存できる', (tester) async {
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('商品管理').last);
    await tester.pumpAndSettle();
    final productScroll = find.descendant(
      of: find.byKey(const Key('products-management-scroll')),
      matching: find.byType(Scrollable),
    );
    final lastProduct = find.byKey(const Key('edit-product-11'));
    await tester.scrollUntilVisible(
      lastProduct,
      200,
      scrollable: productScroll,
    );
    await tester.pumpAndSettle();
    expect(lastProduct.hitTestable(), findsOneWidget);
    await tester.tap(lastProduct);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-name')), '焼きそば');
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final save = find.byKey(const Key('save-product'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(save.hitTestable(), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      (await database.products()).singleWhere((p) => p.id == 'product-11').name,
      '焼きそば',
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.text('レジ').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-search')), '焼きそば');
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('product-product-11'));
    await tester.scrollUntilVisible(
      tile,
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('product-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(controller.order.lines.single.name, '焼きそば');
    expect(controller.order.total, 500);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(844, 390), const Size(667, 375)]) {
    testWidgets('横画面 $size で商品追加・明細の数量変更・会計を完了できる', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await controller.load();
      // 複数明細が画面内に収まらない注文で、末尾へのスクロールも確認する。
      for (final product in controller.products.take(11)) {
        await controller.add(product);
      }
      final lastProduct = controller.products.last;
      await tester.pumpWidget(RegisterApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final productScroll = find
          .descendant(
            of: find.byKey(const Key('product-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(Key('product-${lastProduct.id}')),
        100,
        scrollable: productScroll,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('product-${lastProduct.id}')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(Key('product-${lastProduct.id}')));
      await tester.pumpAndSettle();
      expect(controller.order.quantity, 12);
      expect(tester.takeException(), isNull);

      final openOrder = find.byKey(const Key('open-order'));
      if (openOrder.evaluate().isNotEmpty) {
        await tester.tap(openOrder);
        await tester.pumpAndSettle();
      }
      final orderScroll = find.descendant(
        of: find.byKey(const Key('order-scroll')),
        matching: find.byType(Scrollable),
      );
      final increase = find.byTooltip('${lastProduct.name}を1点増やす');
      await tester.scrollUntilVisible(increase, 100, scrollable: orderScroll);
      await tester.pumpAndSettle();
      expect(increase.hitTestable(), findsOneWidget);
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(controller.order.quantity, 13);
      await tester.tap(find.byTooltip('${lastProduct.name}を1点減らす'));
      await tester.pumpAndSettle();
      expect(controller.order.quantity, 12);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byKey(const Key('checkout')),
        100,
        scrollable: orderScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('cash-10000')));
      await tester.tap(find.byKey(const Key('cash-10000')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('complete-checkout')));
      await tester.tap(find.byKey(const Key('complete-checkout')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-success')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('final-change'))).data,
        '¥4,000',
      );
      await tester.ensureVisible(find.byKey(const Key('next-order')));
      await tester.tap(find.byKey(const Key('next-order')));
      await tester.pumpAndSettle();
      expect(controller.order.lines, isEmpty);
      final now = DateTime.now();
      expect((await database.sales(from: now, to: now)).single.total, 6000);
      expect(tester.takeException(), isNull);
    });
  }
}
