// Minimal hand-written Win32 FFI bindings. Windows only.
// UNVERIFIED: not compiled or run (no Dart/Flutter/Windows in authoring env).
import 'dart:ffi';
import 'package:ffi/ffi.dart';

final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
final DynamicLibrary _shell32 = DynamicLibrary.open('shell32.dll');
final DynamicLibrary _gdi32 = DynamicLibrary.open('gdi32.dll');
final DynamicLibrary _dwmapi = DynamicLibrary.open('dwmapi.dll');

// ---- constants ----
const int gwlStyle = -16;
const int gwlExStyle = -20;
const int wsCaption = 0x00C00000;
const int wsThickFrame = 0x00040000;
const int wsSysMenu = 0x00080000;
const int wsMinimizeBox = 0x00020000;
const int wsMaximizeBox = 0x00010000;
const int wsExToolWindow = 0x00000080;
const int wsExTopmost = 0x00000008;
const int wsExAppWindow = 0x00040000;
const int wsExNoActivate = 0x08000000;
const int wsExLayered = 0x00080000;
const int wsExTransparent = 0x00000020;
const int swpNoSize = 0x0001;
const int swpNoMove = 0x0002;
const int swpNoZOrder = 0x0004;
const int swpNoActivate = 0x0010;
const int swpFrameChanged = 0x0020;
const int swpShowWindow = 0x0040;
const int hwndTopmost = -1;
const int hwndNoTopmost = -2;
const int swHide = 0;
const int swShowNormal = 1;
const int swMinimize = 6;
const int swRestore = 9;
const int monitorDefaultToNearest = 2;
const int gaRootOwner = 3;
const int gwOwner = 4;
const int dwmwaCloaked = 14;
const int processQueryLimitedInformation = 0x1000;
const int tpmReturnCmd = 0x0100;
const int tpmRightButton = 0x0002;
const int mfString = 0x0000;
const int mfSeparator = 0x0800;
const int mfChecked = 0x0008;
const int mfGrayed = 0x0001;
const int shgfiIcon = 0x100;
const int shgfiLargeIcon = 0x0;
const int shgfiUseFileAttributes = 0x10;

// ---- structs ----
final class POINT extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

final class RECT extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class MONITORINFO extends Struct {
  @Uint32()
  external int cbSize;
  external RECT rcMonitor;
  external RECT rcWork;
  @Uint32()
  external int dwFlags;
}

final class MARGINS extends Struct {
  @Int32()
  external int cxLeftWidth;
  @Int32()
  external int cxRightWidth;
  @Int32()
  external int cyTopHeight;
  @Int32()
  external int cyBottomHeight;
}

final class ACCENT_POLICY extends Struct {
  @Int32()
  external int accentState;
  @Int32()
  external int accentFlags;
  @Uint32()
  external int gradientColor;
  @Int32()
  external int animationId;
}

final class WINDOWCOMPOSITIONATTRIBDATA extends Struct {
  @Int32()
  external int attribute;
  external Pointer<Void> data;
  @IntPtr()
  external int sizeOfData;
}

final class ICONINFO extends Struct {
  @Int32()
  external int fIcon;
  @Uint32()
  external int xHotspot;
  @Uint32()
  external int yHotspot;
  @IntPtr()
  external int hbmMask;
  @IntPtr()
  external int hbmColor;
}

final class BITMAP extends Struct {
  @Int32()
  external int bmType;
  @Int32()
  external int bmWidth;
  @Int32()
  external int bmHeight;
  @Int32()
  external int bmWidthBytes;
  @Uint16()
  external int bmPlanes;
  @Uint16()
  external int bmBitsPixel;
  external Pointer<Void> bmBits;
}

final class BITMAPINFOHEADER extends Struct {
  @Uint32()
  external int biSize;
  @Int32()
  external int biWidth;
  @Int32()
  external int biHeight;
  @Uint16()
  external int biPlanes;
  @Uint16()
  external int biBitCount;
  @Uint32()
  external int biCompression;
  @Uint32()
  external int biSizeImage;
  @Int32()
  external int biXPelsPerMeter;
  @Int32()
  external int biYPelsPerMeter;
  @Uint32()
  external int biClrUsed;
  @Uint32()
  external int biClrImportant;
}

/// SHFILEINFOW (MAX_PATH=260 wchar, 80 wchar type name).
final class SHFILEINFOW extends Struct {
  @IntPtr()
  external int hIcon;
  @Int32()
  external int iIcon;
  @Uint32()
  external int dwAttributes;
  @Array(260)
  external Array<Uint16> szDisplayName;
  @Array(80)
  external Array<Uint16> szTypeName;
}

// ---- callback types ----
typedef WndEnumProcNative = Int32 Function(IntPtr hwnd, IntPtr lParam);
typedef MonitorEnumProcNative = Int32 Function(
    IntPtr hMonitor, IntPtr hdc, Pointer<RECT> rect, IntPtr lParam);

// ---- user32 ----
final int Function(Pointer<NativeFunction<WndEnumProcNative>>, int) enumWindows =
    _user32.lookupFunction<
        Int32 Function(Pointer<NativeFunction<WndEnumProcNative>>, IntPtr),
        int Function(Pointer<NativeFunction<WndEnumProcNative>>, int)>('EnumWindows');
final int Function(int, Pointer<Uint32>) getWindowThreadProcessId =
    _user32.lookupFunction<Uint32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)>('GetWindowThreadProcessId');
final int Function(int) isWindowVisible = _user32.lookupFunction<
    Int32 Function(IntPtr), int Function(int)>('IsWindowVisible');
final int Function(int) isIconic = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsIconic');
final int Function(int, int) getWindow = _user32.lookupFunction<
    IntPtr Function(IntPtr, Uint32), int Function(int, int)>('GetWindow');
final int Function(int, int) getWindowLongPtr = _user32.lookupFunction<
    IntPtr Function(IntPtr, Int32), int Function(int, int)>('GetWindowLongPtrW');
final int Function(int, int, int) setWindowLongPtr = _user32.lookupFunction<
    IntPtr Function(IntPtr, Int32, IntPtr),
    int Function(int, int, int)>('SetWindowLongPtrW');
final int Function(int, Pointer<Utf16>, int) getWindowText = _user32
    .lookupFunction<Int32 Function(IntPtr, Pointer<Utf16>, Int32),
        int Function(int, Pointer<Utf16>, int)>('GetWindowTextW');
final int Function(int) getWindowTextLength = _user32.lookupFunction<
    Int32 Function(IntPtr), int Function(int)>('GetWindowTextLengthW');
final int Function(int, Pointer<Utf16>, int) getClassName = _user32
    .lookupFunction<Int32 Function(IntPtr, Pointer<Utf16>, Int32),
        int Function(int, Pointer<Utf16>, int)>('GetClassNameW');
final int Function(int, int, int, int, int, int, int) setWindowPos =
    _user32.lookupFunction<
        Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
        int Function(int, int, int, int, int, int, int)>('SetWindowPos');
final int Function(int, Pointer<RECT>) getWindowRect = _user32.lookupFunction<
    Int32 Function(IntPtr, Pointer<RECT>),
    int Function(int, Pointer<RECT>)>('GetWindowRect');
final int Function(Pointer<POINT>) getCursorPos = _user32.lookupFunction<
    Int32 Function(Pointer<POINT>), int Function(Pointer<POINT>)>('GetCursorPos');
final int Function(int, int) showWindow = _user32.lookupFunction<
    Int32 Function(IntPtr, Int32), int Function(int, int)>('ShowWindow');
final int Function(int) setForegroundWindow = _user32.lookupFunction<
    Int32 Function(IntPtr), int Function(int)>('SetForegroundWindow');
final int Function() getForegroundWindow = _user32
    .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');
final int Function(int) getDpiForWindow = _user32
    .lookupFunction<Uint32 Function(IntPtr), int Function(int)>('GetDpiForWindow');
final int Function(int, int) monitorFromWindow = _user32.lookupFunction<
    IntPtr Function(IntPtr, Uint32), int Function(int, int)>('MonitorFromWindow');
final int Function(int, Pointer<MONITORINFO>) getMonitorInfo =
    _user32.lookupFunction<Int32 Function(IntPtr, Pointer<MONITORINFO>),
        int Function(int, Pointer<MONITORINFO>)>('GetMonitorInfoW');
final int Function(int, Pointer<RECT>,
        Pointer<NativeFunction<MonitorEnumProcNative>>, int) enumDisplayMonitors =
    _user32.lookupFunction<
        Int32 Function(IntPtr, Pointer<RECT>,
            Pointer<NativeFunction<MonitorEnumProcNative>>, IntPtr),
        int Function(int, Pointer<RECT>,
            Pointer<NativeFunction<MonitorEnumProcNative>>, int)>('EnumDisplayMonitors');
final int Function() createPopupMenu =
    _user32.lookupFunction<IntPtr Function(), int Function()>('CreatePopupMenu');
final int Function(int, int, int, Pointer<Utf16>) appendMenu =
    _user32.lookupFunction<Int32 Function(IntPtr, Uint32, IntPtr, Pointer<Utf16>),
        int Function(int, int, int, Pointer<Utf16>)>('AppendMenuW');
final int Function(int, int, int, int, int, int, Pointer<Void>) trackPopupMenu =
    _user32.lookupFunction<
        Int32 Function(IntPtr, Uint32, Int32, Int32, Int32, IntPtr, Pointer<Void>),
        int Function(int, int, int, int, int, int, Pointer<Void>)>('TrackPopupMenu');
final int Function(int) destroyMenu = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('DestroyMenu');
final int Function(int) destroyIcon = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('DestroyIcon');
final int Function(int, Pointer<ICONINFO>) getIconInfo = _user32.lookupFunction<
    Int32 Function(IntPtr, Pointer<ICONINFO>),
    int Function(int, Pointer<ICONINFO>)>('GetIconInfo');
final int Function(Pointer<Utf16>, int, int, int, Pointer<IntPtr>,
        Pointer<Uint32>, int, int) privateExtractIcons =
    _user32.lookupFunction<
        Uint32 Function(Pointer<Utf16>, Int32, Int32, Int32, Pointer<IntPtr>,
            Pointer<Uint32>, Uint32, Uint32),
        int Function(Pointer<Utf16>, int, int, int, Pointer<IntPtr>,
            Pointer<Uint32>, int, int)>('PrivateExtractIconsW');
final int Function(int, Pointer<WINDOWCOMPOSITIONATTRIBDATA>)
    setWindowCompositionAttribute = _user32.lookupFunction<
        Int32 Function(IntPtr, Pointer<WINDOWCOMPOSITIONATTRIBDATA>),
        int Function(int, Pointer<WINDOWCOMPOSITIONATTRIBDATA>)>(
    'SetWindowCompositionAttribute');
final int Function(int, int, Pointer<Utf16>, Pointer<Utf16>) findWindowEx = _user32
    .lookupFunction<IntPtr Function(IntPtr, IntPtr, Pointer<Utf16>, Pointer<Utf16>),
        int Function(int, int, Pointer<Utf16>, Pointer<Utf16>)>('FindWindowExW');
final int Function(int, int, int, int) postMessage = _user32.lookupFunction<
    Int32 Function(IntPtr, Uint32, IntPtr, IntPtr),
    int Function(int, int, int, int)>('PostMessageW');
final int Function(int) getDC =
    _user32.lookupFunction<IntPtr Function(IntPtr), int Function(int)>('GetDC');
final int Function(int, int) releaseDC = _user32.lookupFunction<
    Int32 Function(IntPtr, IntPtr), int Function(int, int)>('ReleaseDC');

// ---- kernel32 ----
final int Function(int, int, int) openProcess = _kernel32.lookupFunction<
    IntPtr Function(Uint32, Int32, Uint32),
    int Function(int, int, int)>('OpenProcess');
final int Function(int) closeHandle = _kernel32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
final int Function(int, int, Pointer<Utf16>, Pointer<Uint32>)
    queryFullProcessImageName = _kernel32.lookupFunction<
        Int32 Function(IntPtr, Uint32, Pointer<Utf16>, Pointer<Uint32>),
        int Function(int, int, Pointer<Utf16>, Pointer<Uint32>)>(
    'QueryFullProcessImageNameW');
final int Function() getCurrentProcessId = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetCurrentProcessId');

// ---- shell32 ----
final int Function(Pointer<Utf16>, int, Pointer<SHFILEINFOW>, int, int)
    shGetFileInfo = _shell32.lookupFunction<
        IntPtr Function(Pointer<Utf16>, Uint32, Pointer<SHFILEINFOW>, Uint32, Uint32),
        int Function(Pointer<Utf16>, int, Pointer<SHFILEINFOW>, int, int)>(
    'SHGetFileInfoW');

// ---- gdi32 ----
final int Function(int) deleteObject = _gdi32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('DeleteObject');
final int Function(int, int, Pointer<Void>) getObject = _gdi32.lookupFunction<
    Int32 Function(IntPtr, Int32, Pointer<Void>),
    int Function(int, int, Pointer<Void>)>('GetObjectW');
final int Function(int, int, int, int, Pointer<Void>, Pointer<BITMAPINFOHEADER>, int)
    getDIBits = _gdi32.lookupFunction<
        Int32 Function(IntPtr, IntPtr, Uint32, Uint32, Pointer<Void>,
            Pointer<BITMAPINFOHEADER>, Uint32),
        int Function(int, int, int, int, Pointer<Void>, Pointer<BITMAPINFOHEADER>,
            int)>('GetDIBits');

// ---- dwmapi ----
final int Function(int, Pointer<MARGINS>) dwmExtendFrameIntoClientArea =
    _dwmapi.lookupFunction<Int32 Function(IntPtr, Pointer<MARGINS>),
        int Function(int, Pointer<MARGINS>)>('DwmExtendFrameIntoClientArea');
final int Function(int, int, Pointer<Void>, int) dwmGetWindowAttribute =
    _dwmapi.lookupFunction<Int32 Function(IntPtr, Uint32, Pointer<Void>, Uint32),
        int Function(int, int, Pointer<Void>, int)>('DwmGetWindowAttribute');

final int Function(int, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, int)
    shellExecute = _shell32.lookupFunction<
        IntPtr Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>,
            Pointer<Utf16>, Int32),
        int Function(int, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>,
            Pointer<Utf16>, int)>('ShellExecuteW');
