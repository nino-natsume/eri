'use strict';
// 无端口窗口模块（主线程拥有窗口）：
// - 用 bun:ffi 加载 webview 原生库（webview-bun 2.4.0 / webview, MIT；见 native/LICENSE）
// - Windows: native/libwebview.dll（缺失时可从 native/dll.js 解压）
// - macOS:   native/libwebview.dylib     Linux: native/libwebview-{x64,arm64}.so（需 webkit2gtk-4.1）
// - 页面直接 set_html，不需要任何 HTTP 服务/端口。
// 注意（本构建实测）：主线程 run() 阻塞期间 bind 回调可重入；跨线程调用
// webview_return/webview_eval 无效，故所有原生调用都必须留在主线程。

const fs = require('fs');
const os = require('os');
const path = require('path');

const LIB_VER = '2.4.0';
const DEFAULT_TITLE = '绘里酱';

function isSupported() {
  if (!(process.versions && process.versions.bun)) return false;
  return process.platform === 'win32' || process.platform === 'darwin' || process.platform === 'linux';
}

function loadFfi() {
  try { return require('bun:ffi'); } catch { return null; }
}

function nativeErrorLog(err) {
  try {
    const log = path.join(os.tmpdir(), 'eri-panel-webview.log');
    fs.appendFileSync(log, new Date().toISOString() + ' ' + err + '\n');
  } catch { /* ignore */ }
}

// 消息框（无控制台时的兜底提示, 尽力而为；自动化测试下不弹）
function msgBox(text, title) {
  if (process.platform !== 'win32') return;
  if (process.env.ERI_PANEL_AUTOTEST) return;
  const ffi = loadFfi();
  if (!ffi) return;
  try {
    const u32 = ffi.dlopen('user32.dll', {
      MessageBoxW: { args: [ffi.FFIType.ptr, ffi.FFIType.ptr, ffi.FFIType.ptr, ffi.FFIType.u32], returns: ffi.FFIType.i32 },
    });
    const w = (s) => ffi.ptr(Buffer.from(String(s) + '\0', 'utf16le'));
    u32.symbols.MessageBoxW(null, w(text), w(title || DEFAULT_TITLE), 0x10);
  } catch { /* ignore */ }
}

// Windows: 优先同目录真实文件；否则把内嵌 base64 解压到 %TEMP%
function materializeWinDll() {
  const local = path.join(__dirname, 'native', 'libwebview.dll');
  try { if (fs.existsSync(local)) return local; } catch { /* ignore */ }

  let b64 = null;
  try { b64 = require('./native/dll.js'); } catch { return null; }
  if (!b64 || typeof b64 !== 'string') return null;

  const buf = Buffer.from(b64, 'base64');
  const dir = path.join(os.tmpdir(), 'eri-panel');
  fs.mkdirSync(dir, { recursive: true });
  const out = path.join(dir, 'libwebview-' + LIB_VER + '.dll');
  let ok = false;
  try { ok = fs.existsSync(out) && fs.statSync(out).size === buf.length; } catch { ok = false; }
  if (!ok) {
    try { fs.writeFileSync(out, buf); } catch {
      const alt = path.join(dir, 'libwebview-' + LIB_VER + '-' + process.pid + '.dll');
      fs.writeFileSync(alt, buf);
      return alt;
    }
  }
  return out;
}

function resolveLib() {
  if (process.platform === 'win32') return materializeWinDll();
  if (process.platform === 'darwin') {
    const p = path.join(__dirname, 'native', 'libwebview.dylib');
    return fs.existsSync(p) ? p : null;
  }
  const arch = process.arch === 'arm64' ? 'arm64' : 'x64';
  const p = path.join(__dirname, 'native', 'libwebview-' + arch + '.so');
  return fs.existsSync(p) ? p : null;
}

function failureHint(platform) {
  const base = '独立窗口不可用（需要 Bun 运行时）。安装 Bun: npm i -g bun';
  if (platform === 'win32') return base + '；若 Bun 已装仍失败，请安装 Microsoft Edge WebView2 运行时。';
  if (platform === 'darwin') return base + ' (brew install oven-sh/bun/bun)。';
  return base + ' (curl -fsSL https://bun.sh/install | bash)；窗口还需 webkit2gtk-4.1（如 sudo apt install libwebkit2gtk-4.1-0）。';
}

const SYMBOLS = (F) => ({
  webview_create: { args: [F.i32, F.ptr], returns: F.ptr },
  webview_set_title: { args: [F.ptr, F.ptr], returns: F.void },
  webview_set_size: { args: [F.ptr, F.i32, F.i32, F.i32], returns: F.void },
  webview_set_html: { args: [F.ptr, F.ptr], returns: F.void },
  webview_bind: { args: [F.ptr, F.ptr, F.function, F.ptr], returns: F.void },
  webview_return: { args: [F.ptr, F.ptr, F.i32, F.ptr], returns: F.void },
  webview_run: { args: [F.ptr], returns: F.void },
  webview_terminate: { args: [F.ptr], returns: F.void },
  webview_destroy: { args: [F.ptr], returns: F.void },
  webview_get_window: { args: [F.ptr], returns: F.ptr },
});

// 任务栏/标题栏图标：从 .ico 或 exe 文件加载（Windows 专用，尽力而为）
function applyWindowIcon(lib, handle, iconFile) {
  if (process.platform !== 'win32') return;
  try {
    const ffi = loadFfi();
    if (!ffi) return;
    const F = ffi.FFIType;
    const u32 = ffi.dlopen('user32.dll', {
      LoadImageW: { args: [F.ptr, F.ptr, F.u32, F.i32, F.i32, F.u32], returns: F.ptr },
      SendMessageW: { args: [F.ptr, F.u32, F.u64, F.i64], returns: F.i64 },
    });
    const hwnd = lib.symbols.webview_get_window(handle);
    if (!hwnd) return;
    const src = iconFile && fs.existsSync(iconFile) ? iconFile : process.execPath;
    const srcPtr = ffi.ptr(Buffer.from(src + '\0', 'utf16le'));
    const LR_LOADFROMFILE = 0x10;
    const IMAGE_ICON = 1;
    const icon = u32.symbols.LoadImageW(null, srcPtr, IMAGE_ICON, 0, 0, LR_LOADFROMFILE);
    if (!icon) return;
    const WM_SETICON = 0x80;
    u32.symbols.SendMessageW(hwnd, WM_SETICON, 0, icon); // ICON_SMALL
    u32.symbols.SendMessageW(hwnd, WM_SETICON, 1, icon); // ICON_BIG
  } catch { /* ignore */ }
}

// 创建窗口。opts: { title, width, height, html, iconFile, onBridge }
// onBridge(payload) 在 run() 阻塞期间被同步调用，必须立即返回可 JSON 化的结果对象。
// 返回 { ok:true, run(), terminate(), destroy() } 或 { ok:false, error }
function openWindow(opts) {
  opts = opts || {};
  if (!isSupported()) {
    return { ok: false, error: '当前运行时不支持独立窗口（需要 Bun 运行时）: ' + failureHint(process.platform) };
  }
  const ffi = loadFfi();
  if (!ffi) return { ok: false, error: 'bun:ffi 不可用' };

  let libPath;
  try { libPath = resolveLib(); }
  catch (e) { return { ok: false, error: '准备 webview 原生库失败: ' + String((e && e.message) || e) }; }
  if (!libPath) return { ok: false, error: '缺少 webview 原生库: ' + failureHint(process.platform) };

  let lib;
  try { lib = ffi.dlopen(libPath, SYMBOLS(ffi.FFIType)); }
  catch (e) { return { ok: false, error: '加载 webview 原生库失败 (' + libPath + '): ' + String((e && e.message) || e) }; }

  const cstr = (s) => ffi.ptr(Buffer.from(String(s) + '\0', 'utf8'));
  const handle = lib.symbols.webview_create(0, null);
  if (!handle) {
    return { ok: false, error: 'webview_create 失败。' + failureHint(process.platform) };
  }

  const S = lib.symbols;
  S.webview_set_title(handle, cstr(opts.title || DEFAULT_TITLE));
  S.webview_set_size(handle, opts.width || 1180, opts.height || 780, 0);

  // bind 回调：主线程阻塞期间可重入执行（已实测）。
  // 注意: JS 侧入参被序列化为 JSON 数组（如 ["{...}"]），需两次解析。
  const bridgeDebug = process.env.ERI_PANEL_BRIDGE_DEBUG;
  const bridge = new ffi.JSCallback((id, req) => {
    if (bridgeDebug) {
      try { fs.appendFileSync(bridgeDebug, 'BRIDGE id=' + id + ' req=' + String(req).slice(0, 300) + '\n'); } catch { /* ignore */ }
    }
    let result = '{"ok":false,"error":"no handler"}';
    try {
      let payload = null;
      try {
        const arr = JSON.parse(req || '[]');
        const raw = Array.isArray(arr) ? arr[0] : arr;
        payload = typeof raw === 'string' ? JSON.parse(raw) : raw;
      } catch { payload = null; }
      const r = opts.onBridge ? opts.onBridge(payload) : undefined;
      result = JSON.stringify(r === undefined ? { ok: true } : r);
    } catch (err) {
      result = JSON.stringify({ ok: false, error: String((err && err.message) || err) });
    }
    try {
      S.webview_return(handle, cstr(id), 0, cstr(result));
      if (bridgeDebug) { try { fs.appendFileSync(bridgeDebug, 'RETURN ok id=' + id + ' result=' + result.slice(0, 160) + '\n'); } catch { /* ignore */ } }
    } catch (e) {
      if (bridgeDebug) { try { fs.appendFileSync(bridgeDebug, 'RETURN ERR ' + String((e && e.message) || e) + '\n'); } catch { /* ignore */ } }
    }
  }, { args: [ffi.FFIType.cstring, ffi.FFIType.cstring], returns: ffi.FFIType.void });

  S.webview_bind(handle, cstr('eriNative'), bridge.ptr, null);
  if (opts.html) S.webview_set_html(handle, cstr(opts.html));
  applyWindowIcon(lib, handle, opts.iconFile);

  return {
    ok: true,
    handle,
    _bridge: bridge, // 保持引用，防止 JSCallback 被 GC
    run() {
      S.webview_run(handle);
      try { S.webview_destroy(handle); } catch { /* ignore */ }
    },
    terminate() {
      try { S.webview_terminate(handle); } catch { /* ignore */ }
    },
  };
}

module.exports = { isSupported, openWindow, msgBox, nativeErrorLog, failureHint };
