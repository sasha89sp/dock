// Loads icons for dock items: image files directly, EXE/DLL/ICO/LNK/folders via Win32.
// UNVERIFIED: not compiled or run in the authoring environment.
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ffi/ffi.dart';

import 'win32_bindings.dart';

class IconService {
  final Map<String, Future<ui.Image?>> _cache = {};

  static const _imageExt = {'.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp'};

  static String expand(String path) {
    return path.replaceAllMapped(RegExp(r'%([^%]+)%'), (m) {
      final v = Platform.environment[m[1]!] ??
          Platform.environment[m[1]!.toUpperCase()];
      return v ?? m[0]!;
    });
  }

  /// [size] is the desired pixel size; it is bucketed to limit cache growth.
  Future<ui.Image?> load(String path, {String? iconPath, int size = 64}) {
    final bucket = size <= 32 ? 32 : size <= 48 ? 48 : size <= 64 ? 64 : size <= 128 ? 128 : 256;
    final key = '${iconPath ?? ''}|$path|$bucket';
    return _cache.putIfAbsent(key, () => _load(path, iconPath, bucket));
  }

  Future<ui.Image?> _load(String path, String? iconPath, int size) async {
    try {
      if (iconPath != null && iconPath.isNotEmpty) {
        final custom = expand(iconPath);
        final img = await _fromAnyFile(custom, size);
        if (img != null) return img;
      }
      if (path.contains('://') || path.endsWith(':')) return null; // URL / ms-settings:
      return await _fromAnyFile(expand(path), size);
    } catch (_) {
      return null;
    }
  }

  /// Splits RocketDock `file?index` (index may be negative = resource id).
  static (String, int) splitIndex(String raw) {
    final q = raw.lastIndexOf('?');
    if (q > 1) {
      final n = int.tryParse(raw.substring(q + 1));
      if (n != null) return (raw.substring(0, q), n);
    }
    return (raw, 0);
  }

  Future<ui.Image?> _fromAnyFile(String raw, int size) async {
    var (path, index) = splitIndex(raw);
    final lower = path.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot < 0 ? '' : lower.substring(dot);
    if (_imageExt.contains(ext)) {
      final f = File(path);
      if (!await f.exists()) return null;
      final codec = await ui.instantiateImageCodec(await f.readAsBytes(),
          targetWidth: size, targetHeight: size);
      return (await codec.getNextFrame()).image;
    }
    if (!Platform.isWindows) return null;
    if (!await FileSystemEntity.type(path).then((t) => t != FileSystemEntityType.notFound)) {
      return null;
    }
    // Arbitrary-size extraction works for exe/dll/ico; others fall back to shell icon.
    // Only DLL/ICL/negative (resource id) indexes are trusted; the large numbers RocketDock
    // stores after EXE paths are not confirmed to be icon indexes, so EXE/ICO use index 0.
    if (!(ext == '.dll' || ext == '.icl' || index < 0)) index = 0;
    if (const {'.exe', '.dll', '.ico', '.ocx', '.scr', '.icl'}.contains(ext)) {
      final hicon = _privateExtract(path, size, index);
      if (hicon != 0) return _hiconToImage(hicon);
    }
    final shell = _shellIcon(path);
    if (shell != 0) return _hiconToImage(shell);
    return null;
  }

  int _privateExtract(String path, int size, int index) {
    final p = path.toNativeUtf16();
    final icons = calloc<IntPtr>();
    final ids = calloc<Uint32>();
    try {
      final n = privateExtractIcons(p, index, size, size, icons, ids, 1, 0);
      if (n == 0 || n == 0xFFFFFFFF) return 0;
      return icons.value;
    } finally {
      calloc.free(p);
      calloc.free(icons);
      calloc.free(ids);
    }
  }

  int _shellIcon(String path) {
    final p = path.toNativeUtf16();
    final info = calloc<SHFILEINFOW>();
    try {
      final r = shGetFileInfo(p, 0, info, sizeOf<SHFILEINFOW>(), shgfiIcon | shgfiLargeIcon);
      return r == 0 ? 0 : info.ref.hIcon;
    } finally {
      calloc.free(p);
      calloc.free(info);
    }
  }

  Future<ui.Image?> _hiconToImage(int hicon) async {
    final info = calloc<ICONINFO>();
    try {
      if (getIconInfo(hicon, info) == 0) return null;
      final color = info.ref.hbmColor;
      final mask = info.ref.hbmMask;
      try {
        if (color == 0) return null;
        final bm = calloc<BITMAP>();
        int w, h;
        try {
          getObject(color, sizeOf<BITMAP>(), bm.cast());
          w = bm.ref.bmWidth;
          h = bm.ref.bmHeight;
        } finally {
          calloc.free(bm);
        }
        if (w <= 0 || h <= 0) return null;
        final px = _dib(color, w, h);
        if (px == null) return null;
        var hasAlpha = false;
        for (var i = 3; i < px.length; i += 4) {
          if (px[i] != 0) {
            hasAlpha = true;
            break;
          }
        }
        Uint8List? m;
        if (!hasAlpha && mask != 0) m = _dib(mask, w, h);
        final rgba = Uint8List(px.length);
        for (var i = 0; i < px.length; i += 4) {
          rgba[i] = px[i + 2];
          rgba[i + 1] = px[i + 1];
          rgba[i + 2] = px[i];
          rgba[i + 3] = hasAlpha ? px[i + 3] : (m != null && m[i] != 0 ? 0 : 255);
        }
        final c = Completer<ui.Image>();
        ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
        return c.future;
      } finally {
        if (color != 0) deleteObject(color);
        if (mask != 0) deleteObject(mask);
      }
    } finally {
      calloc.free(info);
      destroyIcon(hicon);
    }
  }

  /// Reads a bitmap as top-down 32bpp BGRA.
  Uint8List? _dib(int hbm, int w, int h) {
    final hdr = sizeOf<BITMAPINFOHEADER>();
    final bmi = calloc<Uint8>(hdr + 1024).cast<BITMAPINFOHEADER>();
    final buf = calloc<Uint8>(w * h * 4);
    final dc = getDC(0);
    try {
      bmi.ref.biSize = hdr;
      bmi.ref.biWidth = w;
      bmi.ref.biHeight = -h;
      bmi.ref.biPlanes = 1;
      bmi.ref.biBitCount = 32;
      final lines = getDIBits(dc, hbm, 0, h, buf.cast(), bmi, 0);
      if (lines == 0) return null;
      return Uint8List.fromList(buf.asTypedList(w * h * 4));
    } finally {
      releaseDC(0, dc);
      calloc.free(bmi);
      calloc.free(buf);
    }
  }
}
