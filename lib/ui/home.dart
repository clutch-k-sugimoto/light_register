import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../register_controller.dart';
import 'checkout.dart';
import 'data_management.dart';
import 'products.dart';
import 'register.dart';
import 'sales.dart';
import 'theme.dart';

class RegisterHome extends StatefulWidget {
  const RegisterHome({super.key, required this.controller});
  final RegisterController controller;
  @override
  State<RegisterHome> createState() => _RegisterHomeState();
}

class _RegisterHomeState extends State<RegisterHome> {
  int _tab = 0;
  int _salesRevision = 0;
  int _dataRevision = 0;
  final _titles = ['レジ', '商品管理', '売上'];

  void _selectTab(int value) => setState(() {
    _tab = value;
    if (value == 2) _salesRevision++;
  });

  Future<void> _edit([Product? product]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        ProductEditor(controller: widget.controller, product: product),
  );

  Future<void> _checkout() async {
    final sale = await showDialog<Sale>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckoutDialog(controller: widget.controller),
    );
    if (sale != null && mounted) setState(() => _salesRevision++);
  }

  Future<void> _manageData() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DataManagementDialog(
      controller: widget.controller,
      onCleared: (allData) => setState(() {
        _salesRevision++;
        if (allData) {
          _tab = 0;
          _dataRevision++;
        }
      }),
    ),
  );

  void _info() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('オフラインで使えます'),
      content: const SingleChildScrollView(
        child: Text(
          '商品登録・会計・売上確認に、インターネット接続やログインは必要ありません。\n\n'
          '商品、会計途中の注文、売上はこの端末内に保存します。アプリを終了しても残ります。\n\n'
          'アプリの削除や端末の初期化でデータは失われます。端末間の共有・クラウド同期・外部バックアップはありません。\n\n'
          '現金会計・日本円に対応しています。価格は税込の販売価格を入力してください。売上日は会計確定時の端末の日付です。',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= 1000;
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 78,
          titleSpacing: wide ? 28 : 20,
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: amber,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '出店レジ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    wide ? 'LIGHT REGISTER' : _titles[_tab],
                    style: const TextStyle(
                      fontSize: 12,
                      color: muted,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (widget.controller.busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (wide)
              TextButton.icon(
                onPressed: _info,
                icon: const Icon(Icons.phonelink_lock_rounded, size: 18),
                label: Text(
                  wide ? 'この端末に保存・通信不要' : '通信不要',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            if (!wide)
              IconButton(
                tooltip: 'オフライン保存について',
                onPressed: _info,
                icon: const Icon(Icons.phonelink_lock_rounded),
              ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Row(
            children: [
              if (wide) ...[
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: _selectTab,
                  backgroundColor: paper,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.85,
                  indicatorColor: const Color(0xFFFFE3B8),
                  scrollable: true,
                  trailingAtBottom: true,
                  trailing: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IconButton(
                      key: const Key('data-management'),
                      tooltip: 'データ管理',
                      onPressed: widget.controller.busy ? null : _manageData,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: Text('レジ'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.sell_outlined),
                      selectedIcon: Icon(Icons.sell_rounded),
                      label: Text('商品管理'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart_rounded),
                      label: Text('売上'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: !widget.controller.loaded
                    ? EmptyState(
                        icon: Icons.refresh,
                        title: '保存データを再読込してください',
                        message: '会計結果は保存済みです。次の会計を始める前に再読込してください。',
                        action: FilledButton(
                          onPressed: () async {
                            try {
                              await widget.controller.load();
                            } catch (e) {
                              if (context.mounted) showFailure(context, e);
                            }
                          },
                          child: const Text('再読込'),
                        ),
                      )
                    : IndexedStack(
                        key: ValueKey(_dataRevision),
                        index: _tab,
                        children: [
                          RegisterPage(
                            controller: widget.controller,
                            onAddProduct: () => _edit(),
                            onCheckout: _checkout,
                          ),
                          ProductsPage(
                            controller: widget.controller,
                            onEdit: _edit,
                          ),
                          SalesPage(
                            database: widget.controller.database,
                            revision: _salesRevision,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (value) {
                  if (value == 3) {
                    if (!widget.controller.busy) _manageData();
                    return;
                  }
                  _selectTab(value);
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'レジ',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.sell_outlined),
                    selectedIcon: Icon(Icons.sell_rounded),
                    label: '商品管理',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart_rounded),
                    label: '売上',
                  ),
                  NavigationDestination(
                    key: const Key('data-management'),
                    enabled: !widget.controller.busy,
                    icon: const Icon(Icons.settings_outlined),
                    label: 'データ管理',
                  ),
                ],
              ),
      );
    },
  );
}
