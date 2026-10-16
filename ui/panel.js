#!/usr/bin/env node
'use strict';
// 绘里酱管理面板 —— 零依赖本地服务 + 内嵌界面。
// 设置读取/写回 ~/.config/opencode/personality.json；
// 聊天复用“安装时选中的终端 CLI”的非交互模式（子进程 + 流式输出）。
// 既可 `node ui/panel.js` / `eri ui` 运行，也可用 `bun build --compile` 打包为独立 exe。

const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const { spawn } = require('child_process');

const HOME = os.homedir();
const h = (...a) => path.join(HOME, ...a);

const PKG = (() => { try { return require('../package.json'); } catch { return { version: '0.0.0' }; } })();
const BUILTIN_PERSONALITY = (() => { try { return require('../personality.json'); } catch { return null; } })();
const BUILTIN_OPENCODE = (() => { try { return require('../opencode.json'); } catch { return null; } })();

const CONFIG_DIR = h('.config', 'opencode');
const SETTINGS_PATH = path.join(CONFIG_DIR, 'personality.json');

// 终端工具清单（与 index.js / 安装脚本一致）
const TOOLS = [
  { id: 'opencode', name: 'OpenCode', cmd: 'opencode' },
  { id: 'claude', name: 'Claude Code', cmd: 'claude' },
  { id: 'codex', name: 'Codex CLI (OpenAI)', cmd: 'codex' },
  { id: 'gemini', name: 'Gemini CLI (Google)', cmd: 'gemini' },
  { id: 'qwen', name: 'Qwen Code (Alibaba)', cmd: 'qwen' },
  { id: 'aider', name: 'Aider', cmd: 'aider' },
  { id: 'cursor-agent', name: 'Cursor CLI', cmd: 'cursor-agent' },
  { id: 'copilot', name: 'GitHub Copilot CLI', cmd: 'copilot' },
  { id: 'amp', name: 'Amp', cmd: 'amp' },
  { id: 'goose', name: 'Goose (Block)', cmd: 'goose' },
  { id: 'crush', name: 'Crush', cmd: 'crush' },
  { id: 'plandex', name: 'Plandex', cmd: 'plandex' },
  { id: 'fabric', name: 'Fabric', cmd: 'fabric' },
  { id: 'openhands', name: 'OpenHands', cmd: 'openhands' },
  { id: 'devin', name: 'Devin CLI', cmd: 'devin' },
  { id: 'continue', name: 'Continue', cmd: 'continue' },
  { id: 'windsurf', name: 'Windsurf CLI', cmd: 'windsurf' },
  { id: 'tabby', name: 'Tabby', cmd: 'tabby-agent' },
];

// 非交互“一次性”调用参数（提示词以参数传入）
const CHAT_ARGS = {
  opencode: (p) => ['run', p],
  claude: (p) => ['-p', p],
  codex: (p) => ['exec', p],
  gemini: (p) => ['-p', p],
  qwen: (p) => ['-p', p],
  aider: (p) => ['--message', p, '--no-auto-commits', '--yes'],
  copilot: (p) => ['-p', p],
  'cursor-agent': (p) => ['-p', p],
  amp: (p) => ['-x', p],
};

// 仅用于本机/CI 自测的假工具
const ECHO_TOOL = { id: 'echo', name: '（自测）Echo', cmd: '__eri_echo__' };
if (process.env.ERI_PANEL_ECHO === '1') TOOLS.push(ECHO_TOOL);

// ---------------------------------------------------------------- utilities

function commandExists(cmd) {
  const dirs = (process.env.PATH || '').split(path.delimiter).filter(Boolean);
  const exts = process.platform === 'win32'
    ? (process.env.PATHEXT || '.COM;.EXE;.BAT;.CMD').split(';').filter(Boolean)
    : [''];
  for (const d of dirs) {
    for (const ext of exts) {
      const full = path.join(d, cmd + ext);
      try { if (fs.statSync(full).isFile()) return full; } catch { /* keep looking */ }
    }
  }
  return null;
}

function toolInfo(t) {
  const exe = commandExists(t.cmd);
  return { id: t.id, name: t.name, cmd: t.cmd, installed: t.id === 'echo' || !!exe, supported: !!CHAT_ARGS[t.id] || t.id === 'echo' };
}

function loadSettings() {
  try { return JSON.parse(fs.readFileSync(SETTINGS_PATH, 'utf8')); }
  catch {
    if (!BUILTIN_PERSONALITY) return null;
    return JSON.parse(JSON.stringify(BUILTIN_PERSONALITY));
  }
}

function settingsSource() {
  return fs.existsSync(SETTINGS_PATH) ? SETTINGS_PATH : '(内置默认)';
}

function saveSettings(obj) {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
  fs.writeFileSync(SETTINGS_PATH, JSON.stringify(obj, null, 2) + '\n');
}

function activeMood(p) {
  const m = (p && p.mood) || {};
  const name = m.override || m.default || '';
  const found = ((p && p.moods) || []).find((x) => x.name === name);
  return { name, hint: found ? found.hint || '' : '' };
}

function buildHint(s) {
  if (!s || !s.personalities) return '';
  const p = s.personalities[s.active];
  if (!p) return '';
  const md = activeMood(p);
  let t = p.description || '';
  if (md.name) t += '\n\n【当前心情】' + md.name + (md.hint ? '：' + md.hint : '');
  return t;
}

function agentsFromOpencode() {
  const sources = [];
  for (const f of ['opencode.jsonc', 'opencode.json']) {
    try { sources.push(JSON.parse(fs.readFileSync(path.join(CONFIG_DIR, f), 'utf8'))); } catch { /* ignore */ }
  }
  sources.push(BUILTIN_OPENCODE);
  for (const oc of sources) {
    const a = (oc && oc.agent) || {};
    const keys = Object.keys(a);
    if (keys.length) return keys.map((k) => ({ name: k, description: (a[k] && a[k].description) || '' }));
  }
  return [];
}

// Windows: .cmd/.bat 需经 cmd.exe；转义规则与 cross-spawn 完全一致
const META_WIN = /([()\][%!^"`<>&|;, *?])/g;
function escapeCommand(arg) {
  return String(arg).replace(META_WIN, '^$1');
}
function escapeArgument(arg, doubleEscapeMetaChars) {
  arg = String(arg);
  arg = arg.replace(/(?=(\\+?)?)\1"/g, '$1$1\\"');
  arg = arg.replace(/(?=(\\+?)?)\1$/, '$1$1');
  arg = '"' + arg + '"';
  arg = arg.replace(META_WIN, '^$1');
  if (doubleEscapeMetaChars) arg = arg.replace(META_WIN, '^$1');
  return arg;
}
const CMD_SHIM_RE = /node_modules[\\/]\.bin[\\/][^\\/]+\.cmd$/i;

// 命令行一次性格外注意换行：折叠为空格，避免 cmd /c 被拆成多条命令
function flat(s) {
  return String(s).replace(/\r?\n+/g, ' ').trim();
}

function spawnTool(exe, args, cwd) {
  if (process.platform === 'win32' && /\.(cmd|bat)$/i.test(exe)) {
    const dbl = CMD_SHIM_RE.test(exe);
    const line = [escapeCommand(exe), ...args.map((a) => escapeArgument(a, dbl))].join(' ');
    return spawn(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', '"' + line + '"'],
      { cwd, windowsHide: true, windowsVerbatimArguments: true });
  }
  return spawn(exe, args, { cwd, windowsHide: true });
}

// ------------------------------------------------------------------- state

function buildState() {
  const s = loadSettings();
  const list = [];
  if (s && s.personalities) {
    for (const name of Object.keys(s.personalities)) {
      const p = s.personalities[name];
      list.push({
        name,
        moods: (p.moods || []).map((m) => ({ name: m.name, hint: m.hint || '', score: m.score })),
        moodDefault: (p.mood && p.mood.default) || '',
        moodOverride: (p.mood && p.mood.override) || '',
      });
    }
  }
  return {
    version: PKG.version,
    settingsSource: settingsSource(),
    active: (s && s.active) || '',
    personalities: list,
    personalitiesCount: list.length,
    tools: TOOLS.map(toolInfo),
    agents: agentsFromOpencode(),
    home: HOME,
    defaults: BUILTIN_PERSONALITY ? Object.keys(BUILTIN_PERSONALITY.personalities || {}) : [],
  };
}

// ------------------------------------------------------------------- server

function json(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve) => {
    let b = '';
    req.on('data', (c) => { b += c; if (b.length > 5e6) req.destroy(); });
    req.on('end', () => { try { resolve(b ? JSON.parse(b) : {}); } catch { resolve({}); } });
    req.on('error', () => resolve({}));
  });
}

function handleChat(req, res) {
  readBody(req).then((body) => {
    const tool = TOOLS.find((t) => t.id === body.tool) || TOOLS[0];
    const message = String(body.message || '').trim();
    const cwd = body.cwd && fs.existsSync(body.cwd) ? body.cwd : HOME;
    if (!message) return json(res, 400, { error: '空消息' });

    res.writeHead(200, { 'content-type': 'application/x-ndjson; charset=utf-8', 'cache-control': 'no-store', 'x-accel-buffering': 'no' });
    const send = (o) => { try { res.write(JSON.stringify(o) + '\n'); } catch { /* ignore */ } };

    // 自测假工具：不依赖任何 CLI
    if (tool.id === 'echo') {
      send({ t: 'meta', cmd: 'echo', cwd });
      const reply = '收到：' + message;
      let i = 0;
      const timer = setInterval(() => {
        if (i >= reply.length) { clearInterval(timer); send({ t: 'end', code: 0 }); res.end(); return; }
        send({ t: 'out', d: reply.slice(i, i + 2) });
        i += 2;
      }, 20);
      req.on('close', () => clearInterval(timer));
      return;
    }

    const spec = CHAT_ARGS[tool.id];
    if (!spec) { send({ t: 'err', d: '该工具暂不支持非交互调用，无法在面板中聊天。' }); send({ t: 'end', code: -1 }); return res.end(); }

    const exe = commandExists(tool.cmd);
    if (!exe) { send({ t: 'err', d: '未检测到命令：' + tool.cmd }); send({ t: 'end', code: -1 }); return res.end(); }

    let prompt = flat(message);
    if (body.inject !== false) {
      const hint = buildHint(loadSettings());
      if (hint) prompt = flat(hint) + ' --- ' + prompt;
    }

    const args = spec(prompt);
    send({ t: 'meta', cmd: tool.cmd + ' ' + args.slice(0, -1).join(' '), cwd });

    let child;
    try { child = spawnTool(exe, args, cwd); }
    catch (err) { send({ t: 'err', d: String(err.message || err) }); send({ t: 'end', code: -1 }); return res.end(); }

    child.stdout.on('data', (d) => send({ t: 'out', d: d.toString('utf8') }));
    child.stderr.on('data', (d) => send({ t: 'err', d: d.toString('utf8') }));
    child.on('error', (err) => { send({ t: 'err', d: String(err.message || err) }); send({ t: 'end', code: -1 }); res.end(); });
    child.on('close', (code) => { send({ t: 'end', code: code == null ? -1 : code }); res.end(); });
    req.on('close', () => { try { child.kill(); } catch { /* ignore */ } });
  });
}

function handleSettings(req, res) {
  readBody(req).then((body) => {
    const s = loadSettings();
    if (!s || !s.personalities) return json(res, 400, { error: '未找到人格配置' });
    if (body.active && s.personalities[body.active]) s.active = body.active;
    const p = s.personalities[s.active];
    if (p) {
      p.mood = p.mood || {};
      if (body.mood !== undefined) p.mood.override = body.mood || null;
    }
    try { saveSettings(s); } catch (err) { return json(res, 500, { error: String(err.message || err) }); }
    json(res, 200, { ok: true, settingsSource: settingsSource() });
  });
}

function handleOpen(req, res) {
  readBody(req).then((body) => {
    const target = body.path || CONFIG_DIR;
    try { fs.mkdirSync(target, { recursive: true }); } catch { /* ignore */ }
    const cmd = process.platform === 'win32' ? 'explorer' : (process.platform === 'darwin' ? 'open' : 'xdg-open');
    try { spawn(cmd, [target], { detached: true, stdio: 'ignore' }).unref(); } catch { /* ignore */ }
    json(res, 200, { ok: true, target });
  });
}

function handleSync(req, res) {
  const eri = commandExists('eri');
  const entry = path.join(__dirname, '..', 'index.js');
  let child;
  try {
    if (eri) child = spawnTool(eri, ['update'], HOME);
    else if (fs.existsSync(entry)) child = spawnTool(process.execPath, [entry, 'update'], HOME);
    else return json(res, 400, { error: '未找到 eri 命令或 index.js' });
  } catch (err) { return json(res, 500, { error: String(err.message || err) }); }
  let out = '';
  child.stdout.on('data', (d) => { out += d; });
  child.stderr.on('data', (d) => { out += d; });
  child.on('close', (code) => json(res, 200, { ok: code === 0, code, out: out.slice(-4000) }));
  child.on('error', (err) => json(res, 500, { error: String(err.message || err) }));
}

const PAGE = require('./page.js');

function serve(req, res) {
  const u = new URL(req.url, 'http://127.0.0.1');
  const p = u.pathname;
  if (req.method === 'GET' && (p === '/' || p === '/index.html')) {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
    return res.end(PAGE);
  }
  if (req.method === 'GET' && p === '/api/state') return json(res, 200, buildState());
  if (req.method === 'GET' && p === '/api/tools') return json(res, 200, { tools: TOOLS.map(toolInfo) });
  if (req.method === 'POST' && p === '/api/chat') return handleChat(req, res);
  if (req.method === 'POST' && p === '/api/settings') return handleSettings(req, res);
  if (req.method === 'POST' && p === '/api/open') return handleOpen(req, res);
  if (req.method === 'POST' && p === '/api/sync') return handleSync(req, res);
  json(res, 404, { error: 'not found' });
}

function openBrowser(url) {
  const cmd = process.platform === 'win32' ? 'cmd'
    : (process.platform === 'darwin' ? 'open' : 'xdg-open');
  const args = process.platform === 'win32' ? ['/c', 'start', '', url] : [url];
  try { spawn(cmd, args, { detached: true, stdio: 'ignore', windowsHide: true }).unref(); } catch { /* ignore */ }
}

function startPanel(opts) {
  opts = opts || {};
  const argv = process.argv.slice(2);
  const noOpen = argv.includes('--no-open') || opts.open === false;
  const envPort = process.env.ERI_PANEL_PORT;
  const port = envPort ? Number(envPort)
    : (opts.port !== undefined ? Number(opts.port) : 8710);

  const server = http.createServer(serve);
  server.on('error', (err) => {
    if (err && err.code === 'EADDRINUSE' && !process.env.ERI_PANEL_PORT) {
      server.listen(0, '127.0.0.1');
    } else {
      console.error('==> 面板启动失败: ' + (err && err.message));
      process.exitCode = 1;
    }
  });
  server.on('listening', () => {
    const addr = server.address();
    const url = 'http://127.0.0.1:' + addr.port + '/';
    console.log('==> 绘里酱管理面板已启动: ' + url);
    console.log('    设置文件: ' + settingsSource());
    console.log('    按 Ctrl+C 退出');
    if (!noOpen) openBrowser(url);
  });
  server.listen(port, '127.0.0.1');
  return server;
}

if (require.main === module) startPanel();

module.exports = { startPanel, buildState };
