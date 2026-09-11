import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/register_database.dart';
import '../domain/models.dart';
import 'theme.dart';

enum SalesView { daily, product, history }

class SalesPage extends StatefulWidget {
  const SalesPage({super.key, required this.database, required this.revision});
  final RegisterDatabase database;
  final int revision;
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  SalesView _view = SalesView.daily;
  String _preset = '今日';
  late DateTimeRange _range;
  late Future<List<Sale>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant SalesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _refresh();
  }

  void _refresh() {
    final now = DateUtils.dateOnly(DateTime.now());
    if (_preset != '期間指定') {
      _range = DateTimeRange(
        start: _preset == '今月'
            ? DateTime(now.year, now.month)
            : _preset == '直近7日'
            ? DateTime(now.year, now.month, now.day - 6)
            : now,
        end: now,
      );
    }
    _future = widget.database.sales(from: _range.start, to: _range.end);
  }

  Future<void> _chooseRange() async {
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _range,
      helpText: '売上の表示期間',
      saveText: 'この期間を表示',
    );
    if (value != null && mounted) {
      setState(() {
        _preset = '期間指定';
        _range = value;
        _refresh();
      });
    }
  }

  void _detail(Sale sale) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('会計 #${sale.receiptLabel}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${sale.businessDate} ${sale.timeLabel}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
              for (final line in sale.lines) ...[
                Text(
                  line.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                _row(
                  '${yen(line.unitPrice)} × ${line.quantity}',
                  yen(line.total),
                ),
                const SizedBox(height: 16),
              ],
              const Divider(),
              const SizedBox(height: 16),
              _row('合計（税込）', yen(sale.total)),
              const SizedBox(height: 12),
              _row('お預り', yen(sale.received)),
              const SizedBox(height: 12),
              _row('お釣り', yen(sale.change)),
            ],
          ),
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

  Widget _row(String label, String value) => Row(
    children: [
      Expanded(child: Text(label)),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '売上',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton.outlined(
              tooltip: '売上を再読込',
              onPressed: () => setState(_refresh),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'この端末で確定した現金売上',
          style: TextStyle(color: muted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final preset in ['今日', '直近7日', '今月'])
              ChoiceChip(
                label: Text(preset),
                selected: _preset == preset,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _preset = preset;
                  _refresh();
                }),
              ),
            OutlinedButton.icon(
              key: const Key('sales-range'),
              onPressed: _chooseRange,
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: const Text('期間指定'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${dayKey(_range.start)} 〜 ${dayKey(_range.end)}',
          style: const TextStyle(color: muted, fontSize: 14),
        ),
        const SizedBox(height: 22),
        FutureBuilder<List<Sale>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(64),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.storage_rounded,
                title: '売上を読み込めませんでした',
                message: '端末の状態を確認し、再試行してください。',
                action: FilledButton(
                  onPressed: () => setState(_refresh),
                  child: const Text('再試行'),
                ),
              );
            }
            final sales = snapshot.data ?? [];
            final total = sales.fold(0, (n, sale) => n + sale.total);
            final quantity = sales.fold(0, (n, sale) => n + sale.quantity);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final totalCard = Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '売上合計（税込）',
                            style: TextStyle(color: Color(0xFFC1D0D5)),
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              yen(total),
                              key: const Key('sales-total'),
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    final metrics = Surface(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '会計数',
                                  style: TextStyle(color: muted),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${sales.length}件',
                                  key: const Key('sales-count'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '販売点数',
                                  style: TextStyle(color: muted),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '$quantity点',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                    return constraints.maxWidth > 650
                        ? Row(
                            children: [
                              Expanded(child: totalCard),
                              const SizedBox(width: 16),
                              Expanded(child: metrics),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              totalCard,
                              const SizedBox(height: 12),
                              metrics,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<SalesView>(
                    segments: const [
                      ButtonSegment(value: SalesView.daily, label: Text('日別')),
                      ButtonSegment(
                        value: SalesView.product,
                        label: Text('商品別'),
                      ),
                      ButtonSegment(
                        value: SalesView.history,
                        label: Text('会計履歴'),
                      ),
                    ],
                    selected: {_view},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        setState(() => _view = value.single),
                  ),
                ),
                const SizedBox(height: 18),
                if (sales.isEmpty)
                  const EmptyState(
                    icon: Icons.bar_chart_rounded,
                    title: 'この期間の売上はありません',
                    message: 'レジで会計を確定すると、ここに表示されます。',
                  )
                else
                  Surface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        if (_view == SalesView.daily)
                          ...groupByDate(sales).map(
                            (day) => _reportTile(
                              title: DateFormat(
                                'M月d日（E）',
                                'ja_JP',
                              ).format(DateTime.parse(day.date)),
                              subtitle:
                                  '${day.transactions}件の会計 · ${day.quantity}点',
                              amount: yen(day.total),
                              icon: Icons.calendar_today_outlined,
                            ),
                          ),
                        if (_view == SalesView.product)
                          ...groupByProduct(sales).map(
                            (product) => _reportTile(
                              title: product.name,
                              subtitle: '${product.quantity}点',
                              amount: yen(product.total),
                              icon: Icons.sell_outlined,
                            ),
                          ),
                        if (_view == SalesView.history)
                          ...sales.map(
                            (sale) => _reportTile(
                              title:
                                  '${sale.businessDate.substring(5).replaceAll('-', '/')}  ${sale.timeLabel}',
                              subtitle:
                                  '#${sale.receiptLabel} · ${sale.quantity}点',
                              amount: yen(sale.total),
                              icon: Icons.receipt_long_outlined,
                              onTap: () => _detail(sale),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_view == SalesView.product && sales.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      '同じ商品は価格変更前後を合算します。商品名は期間内の最後の会計時点の名称です。',
                      style: TextStyle(fontSize: 14, color: muted),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _reportTile({
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    VoidCallback? onTap,
  }) => Column(
    children: [
      ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: Icon(icon, color: muted),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: muted),
        ),
        trailing: Text(
          amount,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      const Divider(),
    ],
  );
}
