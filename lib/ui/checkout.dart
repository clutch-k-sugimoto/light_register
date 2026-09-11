import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../register_controller.dart';
import 'theme.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key, required this.controller});
  final RegisterController controller;
  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _digits = '';
  bool _saving = false;
  Sale? _sale;
  String? _error;
  int get _received => int.tryParse(_digits) ?? 0;

  void _input(String key) {
    if (_saving) return;
    setState(() {
      _error = null;
      if (key == 'C') {
        _digits = '';
      } else if (key == '⌫') {
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
      } else if (_digits.length + key.length <= 9) {
        _digits = (_digits + key).replaceFirst(RegExp(r'^0+(?=\d)'), '');
      }
    });
  }

  Future<void> _complete() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final sale = await widget.controller.checkout(_received);
      if (mounted) setState(() => _sale = sale);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is RegisterException
              ? e.message
              : '会計を保存できませんでした。注文は残っています。空き容量を確認し、再試行してください。',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.controller.order;
    final sufficient = _received >= order.total && _digits.isNotEmpty;
    return PopScope(
      canPop: !_saving && _sale == null,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _sale != null
                ? _receipt(context, _sale!)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '現金でお会計',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: '注文に戻る',
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _amountRow(
                        '合計 · ${order.quantity}点',
                        yen(order.total),
                        large: true,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: paper,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: lineColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'お預り',
                              style: TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                yen(_received),
                                key: const Key('received-amount'),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final amount in {order.total, 1000, 5000, 10000})
                            ActionChip(
                              key: amount == order.total
                                  ? const Key('exact-amount')
                                  : Key('cash-$amount'),
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      _digits = '$amount';
                                      _error = null;
                                    }),
                              label: Text(
                                amount == order.total ? 'ちょうど' : yen(amount),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (final row in [
                        ['7', '8', '9'],
                        ['4', '5', '6'],
                        ['1', '2', '3'],
                        ['C', '0', '⌫'],
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              for (var i = 0; i < row.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    key: Key('key-${row[i]}'),
                                    onPressed: _saving
                                        ? null
                                        : () => _input(row[i]),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 56),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: row[i] == '⌫'
                                        ? const Icon(
                                            Icons.backspace_outlined,
                                            semanticLabel: '1桁消す',
                                          )
                                        : Text(
                                            row[i],
                                            semanticsLabel: row[i] == 'C'
                                                ? '金額をクリア'
                                                : row[i],
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: sufficient ? const Color(0xFFEAF3EF) : paper,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            _amountRow(
                              'お釣り',
                              sufficient ? yen(_received - order.total) : '—',
                              large: true,
                            ),
                            if (!sufficient && _digits.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${yen(order.total - _received)} 不足しています',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const Key('complete-checkout'),
                        onPressed: sufficient && !_saving ? _complete : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: amber,
                          foregroundColor: ink,
                          minimumSize: const Size(0, 58),
                        ),
                        child: Text(_saving ? '売上を保存中…' : '会計を確定する'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _receipt(BuildContext context, Sale sale) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF3F7B61),
        size: 64,
      ),
      const SizedBox(height: 16),
      Text(
        '会計が完了しました',
        key: const Key('checkout-success'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text(
        '売上をこの端末に保存しました',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 14),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDCF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'お渡しするお釣り',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                yen(sale.change),
                key: const Key('final-change'),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _amountRow('お買上げ', yen(sale.total)),
      const SizedBox(height: 10),
      _amountRow('お預り', yen(sale.received)),
      const SizedBox(height: 16),
      Text(
        '${sale.businessDate} ${sale.timeLabel} · #${sale.receiptLabel}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 13),
      ),
      const SizedBox(height: 28),
      FilledButton(
        key: const Key('next-order'),
        onPressed: () => Navigator.pop(context, sale),
        child: const Text('次のお会計へ'),
      ),
    ],
  );

  Widget _amountRow(String label, String value, {bool large = false}) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: muted)),
      ),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: large ? 28 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  );
}
