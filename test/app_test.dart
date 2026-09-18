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

  testWidgets('最後の商品の販売終了後に検索条件をリセットし、新商品を注文できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await database.saveProduct(
      const Product(id: 'ice', name: 'かき氷', price: 350, category: '甘味'),
    );
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-search')), 'かき氷');
    await tester.tap(find.widgetWithText(ChoiceChip, '甘味'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('商品管理').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-ice')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('この商品の販売を終了'));
    await tester.tap(find.text('この商品の販売を終了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('販売を終了'));
    await tester.pumpAndSettle();
    expect(controller.products, isEmpty);
    await tester.tap(find.text('レジ').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-search')), findsNothing);

    await tester.tap(find.byKey(const Key('first-product')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-name')), '焼きそば');
    await tester.enterText(find.byKey(const Key('product-price')), '500');
    await tester.enterText(find.byKey(const Key('product-category')), 'フード');
    await tester.ensureVisible(find.byKey(const Key('save-product')));
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
    final search = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('product-search')),
        matching: find.byType(EditableText),
      ),
    );
    expect(search.controller.text, isEmpty);
    final product = find.byKey(Key('product-${controller.products.single.id}'));
    expect(product.hitTestable(), findsOneWidget);
    await tester.tap(product);
    await tester.pumpAndSettle();
    expect(controller.order.quantity, 1);
    expect(controller.order.total, 500);
    expect((await database.order()).lines.single.name, '焼きそば');
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

  testWidgets('データ管理は縦横のメニュー末尾から開き、閉じても選択画面と注文を保持する', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await seedSaleAndOrder();
    final draft = controller.order.toMap();
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('売上').last);
    await tester.pumpAndSettle();

    for (final layout in [
      (size: const Size(1194, 834), sidebar: true),
      (size: const Size(834, 1194), sidebar: false),
      (size: const Size(1024, 1366), sidebar: true),
      (size: const Size(390, 844), sidebar: false),
      (size: const Size(667, 375), sidebar: false),
    ]) {
      tester.view.physicalSize = layout.size;
      tester.view.padding = layout.size.width > layout.size.height
          ? const FakeViewPadding(left: 44, right: 44, bottom: 21)
          : const FakeViewPadding(top: 47, bottom: 34);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final management = find.byKey(const Key('data-management'));
      expect(management.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: management),
        findsNothing,
      );
      final navigation = find.byType(
        layout.sidebar ? NavigationRail : NavigationBar,
      );
      expect(
        find.descendant(of: navigation, matching: management),
        findsOneWidget,
      );
      final navigationRect = tester.getRect(navigation);
      final managementRect = tester.getRect(management);
      expect(navigationRect.contains(managementRect.center), isTrue);
      if (layout.sidebar) {
        expect(navigationRect.bottom - managementRect.bottom, closeTo(12, 0.1));
      } else {
        final salesIcon = find.descendant(
          of: navigation,
          matching: find.byIcon(Icons.bar_chart_rounded),
        );
        expect(
          managementRect.center.dx,
          greaterThan(tester.getCenter(salesIcon).dx),
        );
      }

      await tester.tap(management);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete-sales')), findsOneWidget);
      expect(find.byKey(const Key('delete-all-data')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('close-data-management')),
      );
      await tester.tap(find.byKey(const Key('close-data-management')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete-sales')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('sales-total'))).data,
        '¥500',
      );
      expect(controller.order.toMap(), draft);
      expect(tester.takeException(), isNull);
    }
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
