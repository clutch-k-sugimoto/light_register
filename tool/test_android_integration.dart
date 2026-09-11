import 'dart:convert';
import 'dart:io';

/// Runs the native integration test with host-controlled display rotation.
/// Usage: dart run tool/test_android_integration.dart DEVICE_ID
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/test_android_integration.dart DEVICE_ID',
    );
    exitCode = 64;
    return;
  }
  final device = arguments.single;
  final properties = File('android/local.properties');
  final sdkLine = properties.existsSync()
      ? properties.readAsLinesSync().where(
          (line) => line.startsWith('sdk.dir='),
        )
      : <String>[];
  final sdk =
      Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'] ??
      (sdkLine.isEmpty
          ? null
          : sdkLine.first
                .substring('sdk.dir='.length)
                .replaceAll(r'\:', ':')
                .replaceAll(r'\\', r'\'));
  if (sdk == null) {
    throw StateError('Set ANDROID_HOME or run flutter pub get first.');
  }
  final adb = '$sdk/platform-tools/adb${Platform.isWindows ? '.exe' : ''}';
  Future<String> shell(List<String> command) async {
    final result = await Process.run(adb, ['-s', device, 'shell', ...command]);
    if (result.exitCode != 0) {
      throw ProcessException(adb, command, '${result.stderr}', result.exitCode);
    }
    return '${result.stdout}'.trim();
  }

  final rotation = await shell(['wm', 'user-rotation']);
  final savedUserRotation = await shell([
    'settings',
    'get',
    'system',
    'user_rotation',
  ]);
  final dimensions = RegExp(r'(\d+)x(\d+)')
      .allMatches(await shell(['wm', 'size']))
      .last;
  final naturalLandscape =
      int.parse(dimensions[1]!) > int.parse(dimensions[2]!);
  var rotationFailed = false;
  try {
    final process = await Process.start('flutter', [
      'test',
      'integration_test/register_test.dart',
      '--no-pub',
      '-d',
      device,
      '--dart-define=EXTERNAL_TEST_ROTATION=true',
      '--reporter=expanded',
    ], runInShell: Platform.isWindows);
    final output = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asyncMap((line) async {
          stdout.writeln(line);
          final request = RegExp(r'REGISTER_TEST_ROTATION:(landscape|portrait)')
              .firstMatch(line);
          if (request == null) return;
          final landscape = request[1] == 'landscape';
          try {
            await shell([
              'wm',
              'user-rotation',
              'lock',
              landscape == naturalLandscape ? '0' : '1',
            ]);
          } catch (error) {
            rotationFailed = true;
            stderr.writeln('Display rotation failed: $error');
          }
        })
        .drain<void>();
    final errors = process.stderr.forEach(stderr.add);
    final result = await process.exitCode;
    await Future.wait([output, errors]);
    exitCode = rotationFailed ? 1 : result;
  } finally {
    if (savedUserRotation == 'null') {
      await shell(['settings', 'delete', 'system', 'user_rotation']);
    } else {
      await shell([
        'settings',
        'put',
        'system',
        'user_rotation',
        savedUserRotation,
      ]);
    }
    await shell(['wm', 'user-rotation', ...rotation.split(RegExp(r'\s+'))]);
  }
}
