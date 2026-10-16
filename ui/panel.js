#!/usr/bin/env node
'use strict';
// 绘里酱管理面板 —— 无端口纯应用（参考 folia 桌面形态）：
// - 主线程创建系统 WebView 窗口，直接加载内嵌页面（set_html），没有 HTTP 服务/端口/浏览器；
// - 前端经 webview_bind 桥（window.eriNative）提交任务与轮询结果；
// - 后端逻辑跑在 Worker 线程（独立事件循环，可自由 spawn 子进程），
//   产出写入 SharedArrayBuffer 环形队列，由主线程在 bind 回调里取回。
// 运行：`eri ui`（需 Bun），或 `bun ui/panel.js`；Windows 也可直接用打包的 eri-panel.exe。

const fs = require('fs');
const path = require('path');
const { Worker } = require('worker_threads');
const { pathToFileURL } = require('url');

const { createRing, RING_SIZE } = require('./ring.js');
const webviewMod = require('./webview.js');
const PAGE = require('./page.js');

const AUTOTEST = process.env.ERI_PANEL_AUTOTEST;

function pageHtml() {
  if (!AUTOTEST) return PAGE;
  return PAGE.replace('<body>', '<body>\n<script>window.__ERI_AUTOTEST__=1;</script>');
}

// 图标为派生文件（不入库）：缺失时本地按需构造；只读安装目录下静默降级为默认图标。
function ensureIconFile() {
  const iconPath = path.join(__dirname, 'icon.ico');
  try {
    if (fs.existsSync(iconPath)) return iconPath;
    const { buildIcon } = require('./make-icon.js');
    fs.writeFileSync(iconPath, buildIcon().ico);
  } catch { /* ignore */ }
  return iconPath;
}

function main() {
  if (!webviewMod.isSupported()) {
    console.error('==> 独立窗口需要 Bun 运行时。');
    console.error('    安装 Bun: npm i -g bun');
    console.error('    Windows 用户也可直接使用打包好的 eri-panel.exe。');
    process.exit(1);
  }

  const sab = new SharedArrayBuffer(RING_SIZE);
  const ring = createRing(sab);
  const worker = new Worker(new URL('./worker.js', pathToFileURL(__filename)), { workerData: { sab } });
  worker.on('error', (e) => webviewMod.nativeErrorLog('worker: ' + String((e && e.message) || e)));

  let sidSeq = 0;
  let wv = null; // 窗口句柄包装（run 前赋值；bind 回调只在 run 期间触发）

  const onBridge = (msg) => {
    if (!msg || typeof msg !== 'object') return { ok: false, error: 'bad payload' };
    if (msg.op === 'submit') {
      const sid = 'j' + (++sidSeq) + '-' + Date.now().toString(36);
      worker.postMessage({ sid, path: String(msg.path || ''), method: msg.method || 'GET', body: msg.body || {} });
      return { ok: true, sid };
    }
    if (msg.op === 'poll') return { ok: true, msgs: ring.drain() };
    if (msg.op === 'stop') {
      worker.postMessage({ stop: true, sid: String(msg.sid || '') });
      return { ok: true };
    }
    if (msg.op === 'close') {
      if (wv) { try { wv.terminate(); } catch { /* ignore */ } }
      return { ok: true };
    }
    return { ok: false, error: 'unknown op: ' + String(msg.op) };
  };

  wv = webviewMod.openWindow({
    title: '绘里酱',
    width: 1180,
    height: 780,
    html: pageHtml(),
    iconFile: ensureIconFile(),
    onBridge,
  });

  if (!wv.ok) {
    try { worker.terminate(); } catch { /* ignore */ }
    webviewMod.nativeErrorLog(wv.error);
    console.error('==> 面板启动失败: ' + wv.error);
    webviewMod.msgBox(wv.error, '绘里酱 - 启动失败');
    process.exit(1);
  }

  console.log('==> 绘里酱管理面板窗口已打开（关闭窗口即退出；无端口、无浏览器）');
  wv.run(); // 阻塞直到窗口关闭
  try { worker.terminate(); } catch { /* ignore */ }
  process.exit(0);
}

if (require.main === module) main();

module.exports = { main };
