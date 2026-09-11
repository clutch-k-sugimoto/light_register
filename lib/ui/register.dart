import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../register_controller.dart';
import 'theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.controller,
    required this.onAddProduct,
    required this.onCheckout,
  });
  final RegisterController controller;
  final VoidCallback onAddProduct;
  final VoidCallback onCheckout;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String? _category;
  final _search = TextEditingController();

  @override
  void didUpdateWidget(covariant RegisterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.products.isEmpty) {
      if (_search.text.isNotEmpty) _search.clear();
      _category = null;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add(Product product) async {
    try {
      await widget.controller.add(product);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  void _openOrder() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (_, child) => OrderPanel(
          controller: widget.controller,
          onCheckout: () {
            Navigator.pop(context);
            widget.onCheckout();
          },
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      final categories = <String?>[
        null,
        ...widget.controller.products.map((p) => p.category).toSet(),
      ];
      final selected = categories.contains(_category) ? _category : null;
      final products = widget.controller.products
          .where(
            (p) =>
                (selected == null || p.category == selected) &&
                p.name.toLowerCase().contains(_search.text.toLowerCase()),
          )
          .toList();
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CustomScrollView(
              key: const Key('product-scroll'),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '商品を選択',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'タップするごとに1点追加',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: '商品を登録',
                              onPressed: widget.onAddProduct,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                      if (widget.controller.products.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                          child: TextField(
                            key: const Key('product-search'),
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: '商品を検索',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: categories.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) => ChoiceChip(
                              label: Text(
                                categories[index] == null
                                    ? 'すべて'
                                    : categories[index]!.isEmpty
                                    ? '未分類'
                                    : categories[index]!,
                              ),
                              selected: categories[index] == selected,
                              showCheckmark: false,
                              selectedColor: ink,
                              labelStyle: TextStyle(
                                color: categories[index] == selected
                                    ? Colors.white
                                    : ink,
                              ),
                              onSelected: (_) =>
                                  setState(() => _category = categories[index]),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: widget.controller.products.isEmpty
                        ? EmptyState(
                            icon: Icons.storefront_outlined,
                            title: '出店の準備をはじめましょう',
                            message: 'まずは販売する商品を登録。\n通信がなくても、この端末だけで会計できます。',
                            action: FilledButton.icon(
                              key: const Key('first-product'),
                              onPressed: widget.onAddProduct,
                              icon: const Icon(Icons.add),
                              label: const Text('最初の商品を登録'),
                            ),
                          )
                        : const EmptyState(
                            icon: Icons.search_off,
                            title: '商品が見つかりません',
                            message: '検索する名前やカテゴリを変更してください。',
                          ),
                  )
                else
                  SliverLayoutBuilder(
                    builder: (context, grid) {
                      final columns = grid.crossAxisExtent >= 620 ? 3 : 2;
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(16) / 16;
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: 166 * textScale.clamp(1, 2),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: products.length,
                          itemBuilder: (context, index) =>
                              _productTile(products[index]),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          if (!wide)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: lineColor)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('open-order'),
                  onPressed: widget.controller.order.lines.isEmpty
                      ? null
                      : _openOrder,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 24,
                    runSpacing: 6,
                    children: [
                      Text('注文を確認 · ${widget.controller.order.quantity}点'),
                      Text(
                        yen(widget.controller.order.total),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
      return Row(
        children: [
          Expanded(child: content),
          if (wide) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 340,
              child: Container(
                color: Colors.white,
                child: OrderPanel(
                  controller: widget.controller,
                  onCheckout: widget.onCheckout,
                ),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _productTile(Product product) {
    final count = widget.controller.order.lines
        .where((l) => l.productId == product.id)
        .fold(0, (n, l) => n + l.quantity);
    final color = Color(productColors[product.color]);
    return Semantics(
      label: '${product.name}、${product.price}円、注文に追加',
      button: true,
      child: Material(
        color: count > 0 ? color.withValues(alpha: 0.15) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: count > 0 ? color : lineColor,
            width: count > 0 ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('product-${product.id}'),
          onTap: widget.controller.busy ? null : () => _add(product),
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: color, width: 5)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.category.isEmpty ? '未分類' : product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: muted),
                      ),
                    ),
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  yen(product.price),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OrderPanel extends StatelessWidget {
  const OrderPanel({
    super.key,
    required this.controller,
    required this.onCheckout,
  });
  final RegisterController controller;
  final VoidCallback onCheckout;

  Future<void> _change(BuildContext context, OrderLine line, int delta) async {
    try {
      await controller.changeQuantity(line.key, delta);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _clear(BuildContext context) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('注文をクリアしますか？'),
        content: const Text('会計前の商品をすべて取り除きます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('クリアする'),
          ),
        ],
      ),
    );
    if (answer == true) {
      try {
        await controller.clearOrder();
      } catch (e) {
        if (context.mounted) showFailure(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      // 見出しと合計を固定しても明細を操作できる高さがある場合だけ固定する。
      final fixedSections = constraints.maxHeight >= 480 * textScale;
      final header = Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '今回の注文',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: controller.busy || controller.order.lines.isEmpty
                  ? null
                  : () => _clear(context),
              child: const Text('クリア'),
            ),
          ],
        ),
      );
      final summary = Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '合計（${controller.order.quantity}点）',
                    style: const TextStyle(color: muted),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      yen(controller.order.total),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '税込・現金会計',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('checkout'),
              onPressed: controller.busy || controller.order.lines.isEmpty
                  ? null
                  : onCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: amber,
                foregroundColor: ink,
                minimumSize: const Size(0, 58),
              ),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('お会計へ'),
            ),
          ],
        ),
      );
      final orderScroll = CustomScrollView(
        key: const Key('order-scroll'),
        slivers: [
          if (!fixedSections)
            SliverToBoxAdapter(
              child: Column(children: [header, const Divider()]),
            ),
          if (controller.order.lines.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: '注文はまだありません',
                message: '商品を選ぶと\nここに追加されます。',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList.separated(
                itemCount: controller.order.lines.length,
                separatorBuilder: (_, index) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(),
                ),
                itemBuilder: (context, index) =>
                    _orderLine(context, controller.order.lines[index]),
              ),
            ),
          if (!fixedSections)
            SliverToBoxAdapter(
              child: Column(children: [const Divider(), summary]),
            ),
        ],
      );
      if (!fixedSections) return orderScroll;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const Divider(),
          Expanded(child: orderScroll),
          const Divider(),
          summary,
        ],
      );
    },
  );

  Widget _orderLine(BuildContext context, OrderLine line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${yen(line.unitPrice)} / 点',
          style: const TextStyle(color: muted, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  tooltip: '${line.name}を1点減らす',
                  onPressed: controller.busy
                      ? null
                      : () => _change(context, line, -1),
                  icon: const Icon(Icons.remove, size: 20),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '${line.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: '${line.name}を1点増やす',
                  onPressed: controller.busy
                      ? null
                      : () => _change(context, line, 1),
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
            Text(
              yen(line.total),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
      ],
    );
  }
}
