import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:url_launcher/url_launcher.dart';

import 'windows/win32_bindings.dart';

class AppLauncher {
  /// RocketDock special commands and shell namespace paths mapped to ShellExecute targets.
  static String resolveSpecial(String target) {
    if (target == '[RecycleBin]') return 'shell:RecycleBinFolder';
    if (target.startsWith('::{')) return 'shell:$target';
    return target;
  }

  static String expandEnv(String path) => path.replaceAllMapped(RegExp(r'%([^%]+)%'), (m) {
        return Platform.environment[m[1]!] ?? Platform.environment[m[1]!.toUpperCase()] ?? m[0]!;
      });

  Future<void> launch(String target,
      {bool isUrl = false, String arguments = '', String workingDirectory = ''}) async {
    if (target.trim().isEmpty) return;
    if (isUrl || target.startsWith('https://') || target.startsWith('http://')) {
      final uri = Uri.tryParse(target);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Не удалось открыть ссылку: $target');
      }
      return;
    }
    if (!Platform.isWindows) throw UnsupportedError('Запуск файлов поддерживается в Windows.');
    final file = expandEnv(resolveSpecial(target));
    final f = file.toNativeUtf16();
    final verb = 'open'.toNativeUtf16();
    final args = arguments.isEmpty ? nullptr.cast<Utf16>() : expandEnv(arguments).toNativeUtf16();
    final dir = workingDirectory.isEmpty
        ? nullptr.cast<Utf16>()
        : expandEnv(workingDirectory).toNativeUtf16();
    try {
      final r = shellExecute(0, verb, f, args, dir, swShowNormal);
      // ShellExecuteW returns a value > 32 on success.
      if (r <= 32) throw Exception('Windows не смогла запустить: $target (код $r)');
    } finally {
      calloc.free(f);
      calloc.free(verb);
      if (args != nullptr) calloc.free(args);
      if (dir != nullptr) calloc.free(dir);
    }
  }

  /// Opens Explorer with the item selected.
  Future<void> showInFolder(String path) async {
    if (!Platform.isWindows) return;
    await Process.start('explorer.exe', ['/select,', expandEnv(path)],
        mode: ProcessStartMode.detached);
  }
}
