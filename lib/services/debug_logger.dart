import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DebugLogger {
  static const _maxBytes = 50 * 1024 * 1024; // rotate at 50 MB; two files = 100 MB total
  static File? _file;

  static Future<File> _logFile() async {
    if (_file != null) return _file!;
    final dir = await getExternalStorageDirectory();
    _file = File('${dir!.path}/debug.log');
    return _file!;
  }

  static Future<void> log(String tag, String message) async {
    try {
      final file = await _logFile();
      final now = DateTime.now().toLocal().toIso8601String().replaceFirst('T', ' ');
      final ts = now.length > 23 ? now.substring(0, 23) : now;
      await file.writeAsString('$ts [$tag] $message\n', mode: FileMode.append);
      if (await file.length() > _maxBytes) {
        await File('${file.path}.1').writeAsBytes(await file.readAsBytes());
        await file.writeAsString('--- log rotated ---\n');
      }
    } catch (_) {}
  }

  static Future<String> get path async => (await _logFile()).path;
}
