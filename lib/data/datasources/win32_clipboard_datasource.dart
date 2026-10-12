import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Win32 API を用いた完全イベント駆動型クリップボードデータソース
class Win32ClipboardDatasource {
  Win32ClipboardDatasource();

  final StreamController<String> _textController =
      StreamController<String>.broadcast();

  /// クリップボード更新時にプレーンテキストを発行するストリーム
  Stream<String> get onClipboardChanged => _textController.stream;

  bool _isListening = false;

  /// 現在監視中かどうか
  bool get isListening => _isListening;

  HWND? _hwnd;
  Pointer<Utf16>? _classNameUtf16;
  NativeCallable<WNDPROC>? _wndProcCallback;
  static Win32ClipboardDatasource? _activeInstance;

  static int _windowProc(
    Pointer hwndPtr,
    int uMsg,
    int wParam,
    int lParam,
  ) {
    if (uMsg == WM_CLIPBOARDUPDATE) {
      _activeInstance?._handleClipboardUpdate();
      return 0;
    }
    return DefWindowProc(
      HWND(hwndPtr),
      uMsg,
      WPARAM(wParam),
      LPARAM(lParam),
    );
  }

  /// クリップボードの監視を開始（メッセージ専用ウィンドウ作成とリスナー登録）
  void start() {
    if (_isListening || !Platform.isWindows) return;

    _activeInstance = this;

    final classNameStr =
        'CopyLotClipboardListener_${DateTime.now().microsecondsSinceEpoch}';
    _classNameUtf16 = classNameStr.toNativeUtf16();
    final classNamePWSTR = PWSTR(_classNameUtf16!);
    final classNamePCWSTR = PCWSTR(_classNameUtf16!);

    _wndProcCallback = NativeCallable<WNDPROC>.isolateLocal(
      _windowProc,
      exceptionalReturn: 0,
    );

    final wndClass = calloc<WNDCLASS>()
      ..ref.lpfnWndProc = _wndProcCallback!.nativeFunction
      ..ref.lpszClassName = classNamePWSTR;

    try {
      RegisterClass(wndClass);
    } finally {
      free(wndClass);
    }

    final createRes = CreateWindowEx(
      WINDOW_EX_STYLE(0),
      classNamePCWSTR,
      classNamePCWSTR,
      WINDOW_STYLE(0),
      0,
      0,
      0,
      0,
      HWND(Pointer.fromAddress(-3)), // HWND_MESSAGE
      HMENU(nullptr),
      HINSTANCE(nullptr),
      nullptr,
    );

    _hwnd = createRes.value;

    final addRes = AddClipboardFormatListener(_hwnd!);
    if (addRes.value) {
      _isListening = true;
    }
  }

  /// クリップボードの監視を停止
  void stop() {
    if (!_isListening) return;

    if (_hwnd != null) {
      RemoveClipboardFormatListener(_hwnd!);
      DestroyWindow(_hwnd!);
      _hwnd = null;
    }

    if (_classNameUtf16 != null) {
      UnregisterClass(PCWSTR(_classNameUtf16!), HINSTANCE(nullptr));
      free(_classNameUtf16!);
      _classNameUtf16 = null;
    }

    _wndProcCallback?.close();
    _wndProcCallback = null;

    if (_activeInstance == this) {
      _activeInstance = null;
    }

    _isListening = false;
  }

  void _handleClipboardUpdate() {
    scheduleMicrotask(() async {
      final text = await getClipboardText();
      if (text != null && !_textController.isClosed) {
        _textController.add(text);
      }
    });
  }

  /// 現在のクリップボードからプレーンテキスト (CF_UNICODETEXT) を取得
  ///
  /// 他プロセスがクリップボードを排他ロックしている場合、[maxRetries] 回まで
  /// [retryInterval] 間隔で再試行（リトライ）を行います。
  /// プレーンテキスト形式以外のデータ（画像・ファイル等）の場合は再試行せず即座に null を返します。
  Future<String?> getClipboardText({
    int maxRetries = 10,
    Duration retryInterval = const Duration(milliseconds: 15),
  }) async {
    if (!Platform.isWindows) return null;

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final openRes = OpenClipboard(HWND(nullptr));
      if (!openRes.value) {
        // 排他ロック競合中: リトライ回数が残っていれば待機して再試行
        if (attempt < maxRetries - 1) {
          await Future<void>.delayed(retryInterval);
          continue;
        }
        return null;
      }

      try {
        // プレーンテキスト形式のみ対象 (画像・ファイル等はリトライ不要で終了)
        if (!IsClipboardFormatAvailable(CF_UNICODETEXT).value) {
          return null;
        }

        final hData = GetClipboardData(CF_UNICODETEXT);
        if (hData.value.address == 0) {
          return null;
        }

        final hGlobal = HGLOBAL(Pointer.fromAddress(hData.value.address));
        final lockRes = GlobalLock(hGlobal);
        final pData = lockRes.value;
        if (pData.address == 0) {
          return null;
        }

        try {
          final text = pData.cast<Utf16>().toDartString();
          return text;
        } finally {
          GlobalUnlock(hGlobal);
        }
      } finally {
        CloseClipboard();
      }
    }

    return null;
  }

  /// 現在のクリップボードからプレーンテキスト (CF_UNICODETEXT) を同期的に取得（再試行なし）
  String? getClipboardTextSync() {
    if (!Platform.isWindows) return null;

    final openRes = OpenClipboard(HWND(nullptr));
    if (!openRes.value) {
      return null;
    }

    try {
      if (!IsClipboardFormatAvailable(CF_UNICODETEXT).value) {
        return null;
      }

      final hData = GetClipboardData(CF_UNICODETEXT);
      if (hData.value.address == 0) {
        return null;
      }

      final hGlobal = HGLOBAL(Pointer.fromAddress(hData.value.address));
      final lockRes = GlobalLock(hGlobal);
      final pData = lockRes.value;
      if (pData.address == 0) {
        return null;
      }

      try {
        final text = pData.cast<Utf16>().toDartString();
        return text;
      } finally {
        GlobalUnlock(hGlobal);
      }
    } finally {
      CloseClipboard();
    }
  }

  /// リソースを完全に解放
  void dispose() {
    stop();
    _textController.close();
  }
}
