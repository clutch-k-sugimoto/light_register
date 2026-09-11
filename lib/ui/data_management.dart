import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../register_controller.dart';
import 'theme.dart';

class DataManagementDialog extends StatefulWidget {
  const DataManagementDialog({
    super.key,
    required this.controller,
    required this.onCleared,
  });

  final RegisterController controller;
  final ValueChanged<bool> onCleared;

  @override
  State<DataManagementDialog> createState() => _DataManagementDialogState();
}

class _DataManagementDialogState extends State<DataManagementDialog> {
  bool _pending = false;
  bool _deleting = false;
  String? _message;
  bool _failed = false;

  Future<void> _clear({required bool allData}) async {
    if (_pending || widget.controller.busy) return;
    setState(() {
      _pending = true;
      _message = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(allData ? 'すべてのデータを消去しますか？' : '売上記録をすべて消去しますか？'),
          content: SingleChildScrollView(
            child: Text(
              allData
                  ? 'この端末の登録商品（販売終了済みを含む）、会計前の注文、全期間の売上・会計明細をすべて消去します。\n\nこの操作は取り消せません。'
                  : 'この端末の全期間の売上・会計明細を消去します。売上画面の表示期間にかかわらず、すべての売上が対象です。\n\n登録商品と会計前の注文は残ります。\n\nこの操作は取り消せません。',
            ),
          ),
          actions: [
            TextButton(
              key: const Key('cancel-data-deletion'),
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: Key(allData ? 'confirm-delete-all' : 'confirm-delete-sales'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(allData ? '全データを消去する' : '全売上記録を消去する'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _deleting = true);
      if (allData) {
        await widget.controller.clearAllData();
      } else {
        await widget.controller.clearSales();
      }
      if (!mounted) return;
      widget.onCleared(allData);
      setState(() {
        _failed = false;
        _message = allData
            ? '全データを消去し、レジを初期状態に戻しました。'
            : 'すべての売上記録を消去しました。商品と会計前の注文は残しています。';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = e is RegisterException
              ? e.message
              : '消去できませんでした。データは変更していません。端末の状態を確認して再試行してください。';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _pending = false;
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_pending,
    child: Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('データ管理', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                '消去する対象を選んでください。確認画面で実行するまで、データは変更されません。',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 24),
              const Text(
                '売上記録消去',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('全期間の売上・会計明細を消去します。商品と会計前の注文は残ります。'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('delete-sales'),
                onPressed: _pending ? null : () => _clear(allData: false),
                icon: const Icon(Icons.delete_outline),
                label: const Text('売上記録を消去'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              const Text(
                'データ全消去',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('登録商品（販売終了済みを含む）、会計前の注文、全期間の売上・会計明細をすべて消去します。'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('delete-all-data'),
                onPressed: _pending ? null : () => _clear(allData: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('データを全消去'),
              ),
              if (_deleting)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('消去中…'),
                      ],
                    ),
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      key: const Key('data-deletion-result'),
                      style: TextStyle(
                        color: _failed
                            ? Theme.of(context).colorScheme.error
                            : ink,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              TextButton(
                key: const Key('close-data-management'),
                onPressed: _pending ? null : () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
