import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DebugLogger {
  static const _maxBytes = 50 * 1024 * 1024;
  static File? _file;
  static Future<void> _queue = Future.value();

  static Future<File> _logFile() async {
    if (_file != null) return _file!;
    final dir = await getExternalStorageDirectory();
    _file = File('${dir!.path}/debug.log');
    return _file!;
  }

  // Synchronous entry point — chains onto the write queue so concurrent calls
  // never interleave in the file.
  static void log(String tag, String message) {
    _queue = _queue.then((_) => _write(tag, message));
  }

  static Future<void> _write(String tag, String message) async {
    try {
      final file = await _logFile();
      final now  = DateTime.now().toLocal().toIso8601String().replaceFirst('T', ' ');
      final ts   = now.length > 23 ? now.substring(0, 23) : now;
      await file.writeAsString('$ts [$tag] $message\n', mode: FileMode.append);
      if (await file.length() > _maxBytes) {
        await File('${file.path}.1').writeAsBytes(await file.readAsBytes());
        await file.writeAsString('--- log rotated ---\n');
      }
    } catch (_) {}
  }

  static Future<String> get path async => (await _logFile()).path;
}
