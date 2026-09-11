import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:light_register/data/register_database.dart';
import 'package:light_register/domain/models.dart';
import 'package:light_register/main.dart';
import 'package:light_register/register_controller.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> rotateTo(
    WidgetTester tester,
    DeviceOrientation orientation,
  ) async {
    final landscape = orientation == DeviceOrientation.landscapeLeft;
    await SystemChrome.setPreferredOrientations([orientation]);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final size = tester.view.physicalSize;
      if ((size.width > size.height) == landscape) break;
    }
    await tester.pumpAndSettle();
    final size = tester.view.physicalSize;
    expect(size.width > size.height, landscape);
    expect(tester.takeException(), isNull);
  }

  testWidgets('ネイティブSQLiteで注文復元、会計、売上復元、売上消去、全消去が動作する', (tester) async {
    final file = '${await getDatabasesPath()}/integration-${newId()}.db';
    var database = await RegisterDatabase.open(filePath: file);
    var controller = RegisterController(database);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await database.close();
      await deleteDatabase(file);
      await SystemChrome.setPreferredOrientations([]);
    });
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('first-product')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-name')), '焼きそば');
    await tester.enterText(find.byKey(const Key('product-price')), '500');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.ensureVisible(find.byKey(const Key('save-product')));
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
    final productId = controller.products.single.id;
    await tester.tap(find.byKey(Key('product-$productId')));
    await tester.pumpAndSettle();

    // Recreate the entire controller and reopen the native database file.
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await database.close();
    database = await RegisterDatabase.open(filePath: file);
    controller = RegisterController(database);
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    expect(controller.order.total, 500);
    expect(controller.products.single.name, '焼きそば');
    await rotateTo(tester, DeviceOrientation.landscapeLeft);
    if (find.byKey(const Key('open-order')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('open-order')));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byTooltip('焼きそばを1点増やす'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('焼きそばを1点増やす'));
    await tester.pumpAndSettle();
    expect(controller.order.total, 1000);
    await tester.tap(find.byTooltip('焼きそばを1点減らす'));
    await tester.pumpAndSettle();
    expect(controller.order.total, 500);
    await tester.ensureVisible(find.byKey(const Key('checkout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkout')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cash-1000')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cash-1000')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('complete-checkout')));
    await tester.tap(find.byKey(const Key('complete-checkout')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('final-change'))).data,
      '¥500',
    );
    await tester.ensureVisible(find.byKey(const Key('next-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('next-order')));
    await tester.pumpAndSettle();
    await rotateTo(tester, DeviceOrientation.portraitUp);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await database.close();
    database = await RegisterDatabase.open(filePath: file);
    controller = RegisterController(database);
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    expect(controller.order.lines, isEmpty);
    final today = DateTime.now();
    final sales = await database.sales(from: today, to: today);
    expect(sales, hasLength(1));
    expect(sales.single.change, 500);
    await tester.tap(find.text('売上').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('sales-total'))).data,
      '¥500',
    );

    // Sales deletion must retain registered products and the in-progress order.
    await controller.add(controller.products.single);
    final retainedOrderId = controller.order.id;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('data-management')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-sales')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-sales')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('close-data-management')));
    await tester.tap(find.byKey(const Key('close-data-management')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('sales-total'))).data,
      '¥0',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await database.close();
    database = await RegisterDatabase.open(filePath: file);
    controller = RegisterController(database);
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    expect(controller.products, hasLength(1));
    expect(controller.order.id, retainedOrderId);
    expect(controller.order.total, 500);
    expect(await database.sales(from: today, to: today), isEmpty);

    // Recreate sale data and verify that a full reset removes every record.
    await controller.checkout(1000);
    await controller.add(controller.products.single);
    const archived = Product(id: 'archived-test', name: '販売終了商品', price: 100);
    await database.saveProduct(archived);
    await database.archiveProduct(archived.id);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('data-management')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('delete-all-data')));
    await tester.tap(find.byKey(const Key('delete-all-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-all')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('close-data-management')));
    await tester.tap(find.byKey(const Key('close-data-management')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first-product')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await database.close();
    database = await RegisterDatabase.open(filePath: file);
    controller = RegisterController(database);
    await tester.pumpWidget(RegisterApp(controller: controller));
    await tester.pumpAndSettle();
    expect(controller.products, isEmpty);
    expect(controller.order.lines, isEmpty);
    expect(await database.db.query('products'), isEmpty);
    expect(await database.db.query('sales'), isEmpty);
    expect(find.byKey(const Key('first-product')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
