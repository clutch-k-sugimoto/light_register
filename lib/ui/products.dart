import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../register_controller.dart';
import 'theme.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  final RegisterController controller;
  final Future<void> Function([Product? product]) onEdit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('商品管理', style: Theme.of(context).textTheme.headlineMedium),
            FilledButton.icon(
              key: const Key('new-product'),
              onPressed: () => onEdit(),
              icon: const Icon(Icons.add),
              label: const Text('商品を登録'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${controller.products.length}商品 · 価格は税込',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: controller.products.isEmpty
              ? const EmptyState(
                  icon: Icons.sell_outlined,
                  title: '販売する商品を登録',
                  message: '商品名と販売価格を登録すると、\nレジに商品ボタンが並びます。',
                )
              : ListView.separated(
                  itemCount: controller.products.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = controller.products[index];
                    return Surface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: ListTile(
                        key: Key('edit-${product.id}'),
                        onTap: () => onEdit(product),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 44,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(
                              productColors[product.color],
                            ).withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.sell_outlined, color: ink),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${product.category.isEmpty ? '未分類' : product.category} · ${yen(product.price)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.controller, this.product});
  final RegisterController controller;
  final Product? product;
  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _category;
  late final String _id;
  late int _color;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?.name ?? '');
    _price = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _category = TextEditingController(text: widget.product?.category ?? '');
    _color = widget.product?.color ?? 0;
    _id = widget.product?.id ?? newId();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveProduct(
        Product(
          id: _id,
          name: _name.text.trim(),
          price: int.parse(_price.text),
          category: _category.text.trim(),
          color: _color,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is RegisterException
              ? e.message
              : '保存できませんでした。空き容量を確認し、再試行してください。',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この商品の販売を終了しますか？'),
        content: const Text('レジの商品一覧から取り除きます。過去の売上と、追加済みの注文は残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('販売を終了'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.controller.archiveProduct(_id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = '保存できませんでした。再試行してください。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.product == null ? '商品を登録' : '商品を編集',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('product-name'),
                  controller: _name,
                  maxLength: 40,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '商品名',
                    hintText: '例：焼きそば',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '商品名を入力してください'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('product-price'),
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: '販売価格（税込）',
                    suffixText: '円',
                    hintText: '500',
                  ),
                  validator: (value) => int.tryParse(value ?? '') == null
                      ? '0〜999,999円で入力してください'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('product-category'),
                  controller: _category,
                  maxLength: 20,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'カテゴリ（任意）',
                    hintText: '例：フード',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '商品ボタンの色',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: List.generate(
                    productColors.length,
                    (index) => Semantics(
                      label: '商品カラー ${index + 1}',
                      selected: index == _color,
                      child: IconButton.filledTonal(
                        onPressed: _saving
                            ? null
                            : () => setState(() => _color = index),
                        style: IconButton.styleFrom(
                          backgroundColor: Color(productColors[index]),
                          minimumSize: const Size(48, 48),
                        ),
                        icon: Icon(
                          index == _color ? Icons.check : Icons.circle,
                          color: index == _color ? ink : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.product != null) ...[
                  const SizedBox(height: 18),
                  const Text(
                    '価格の変更は、変更後に追加した商品から反映します。過去の売上は変わりません。',
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('キャンセル'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('save-product'),
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? '保存中…' : '保存する'),
                      ),
                    ),
                  ],
                ),
                if (widget.product != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _saving ? null : _archive,
                      child: Text(
                        'この商品の販売を終了',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
