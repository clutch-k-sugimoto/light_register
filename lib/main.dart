import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/register_database.dart';
import 'register_controller.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RegisterApp());
}

class RegisterApp extends StatefulWidget {
  const RegisterApp({super.key, this.controller});
  final RegisterController? controller;
  @override
  State<RegisterApp> createState() => _RegisterAppState();
}

class _RegisterAppState extends State<RegisterApp> {
  RegisterController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => _error = null);
    RegisterDatabase? opened;
    try {
      if (widget.controller == null) opened = await RegisterDatabase.open();
      final controller = widget.controller ?? RegisterController(opened!);
      await controller.load();
      if (!mounted) {
        if (widget.controller == null) {
          controller.dispose();
          await opened?.close();
        }
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await opened?.close();
      if (mounted) {
        setState(() => _error = '端末の保存データを開けませんでした。\n空き容量を確認して、再試行してください。');
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller?.database.close();
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '出店レジ',
    debugShowCheckedModeBanner: false,
    theme: registerTheme(),
    locale: const Locale('ja'),
    supportedLocales: const [Locale('ja')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: _controller != null
        ? RegisterHome(controller: _controller!)
        : Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storage_rounded, size: 48),
                          const SizedBox(height: 20),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _open,
                            child: const Text('再試行'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
  );
}
