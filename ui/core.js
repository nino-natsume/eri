'use strict';
// 面板后端核心：人格配置读写、工具探测、聊天子进程（流式）。
// 只负责逻辑与子进程；传输层（窗口 bind + 环形队列）在 panel.js / worker.js。

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const HOME = os.homedir();
const h = (...a) => path.join(HOME, ...a);
const IS_COMPILED = typeof Bun !== 'undefined' && Bun.isStandaloneExecutable;

const PKG = (() => { try { return require('../package.json'); } catch { return { version: '0.0.0' }; } })();
const BUILTIN_PERSONALITY = (() => { try { return require('../personality.json'); } catch { return null; } })();
const BUILTIN_OPENCODE = (() => { try { return require('../opencode.json'); } catch { return null; } })();

const CONFIG_DIR = h('.config', 'opencode');
const SETTINGS_PATH = path.join(CONFIG_DIR, 'personality.json');
const UI_STATE_PATH = path.join(CONFIG_DIR, '.eri-panel.json');

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

function loadUiState() {
  try { return JSON.parse(fs.readFileSync(UI_STATE_PATH, 'utf8')); } catch { return {}; }
}

function saveUiState(obj) {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
  fs.writeFileSync(UI_STATE_PATH, JSON.stringify(obj, null, 2) + '\n');
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

// 当前运行中的子智慧体：从 opencode 数据目录读取最近活跃会话的 agent（只读、自动跟随）。
// bun:sqlite 仅在 worker（bun）运行时加载；node 下静默返回空。
function opencodeDataDir() {
  const base = process.env.XDG_DATA_HOME || h('.local', 'share');
  return path.join(base, 'opencode');
}
function currentSubagent() {
  try {
    const dbPath = path.join(opencodeDataDir(), 'opencode.db');
    if (!fs.existsSync(dbPath)) return '';
    const { Database } = require('bun:sqlite');
    const db = new Database(dbPath, { readonly: true });
    let row = null;
    try { row = db.query('SELECT agent FROM session ORDER BY time_updated DESC LIMIT 1').get(); }
    finally { db.close(); }
    return (row && row.agent) || '';
  } catch { return ''; }
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
  const agents = agentsFromOpencode();
  const rawAgent = currentSubagent();
  return {
    version: PKG.version,
    settingsSource: settingsSource(),
    active: (s && s.active) || '',
    personalities: list,
    personalitiesCount: list.length,
    tools: TOOLS.map(toolInfo),
    agents,
    currentAgent: agents.some((a) => a.name === rawAgent) ? rawAgent : '',
    home: HOME,
    defaults: BUILTIN_PERSONALITY ? Object.keys(BUILTIN_PERSONALITY.personalities || {}) : [],
  };
}

// ------------------------------------------------------------------- jobs

function openJob(body) {
  const target = body.path || CONFIG_DIR;
  try { fs.mkdirSync(target, { recursive: true }); } catch { /* ignore */ }
  const cmd = process.platform === 'win32' ? 'explorer' : (process.platform === 'darwin' ? 'open' : 'xdg-open');
  try { spawn(cmd, [target], { detached: true, stdio: 'ignore' }).unref(); } catch { /* ignore */ }
  return { status: 200, body: { ok: true, target } };
}

function syncJob() {
  return new Promise((resolve) => {
    const eri = commandExists('eri');
    const entry = path.join(__dirname, '..', 'index.js');
    let child;
    try {
      if (eri) child = spawnTool(eri, ['update'], HOME);
      else if (!IS_COMPILED && fs.existsSync(entry)) child = spawnTool(process.execPath, [entry, 'update'], HOME);
      else return resolve({ status: 400, body: { error: IS_COMPILED ? '未安装 eri 命令（npm i -g eri-ai），无法同步' : '未找到 eri 命令或 index.js' } });
    } catch (err) { return resolve({ status: 500, body: { error: String((err && err.message) || err) } }); }
    let out = '';
    child.stdout.on('data', (d) => { out += d; });
    child.stderr.on('data', (d) => { out += d; });
    child.on('close', (code) => resolve({ status: 200, body: { ok: code === 0, code, out: out.slice(-4000) } }));
    child.on('error', (err) => resolve({ status: 500, body: { error: String((err && err.message) || err) } }));
  });
}

function chatJob(body, ctx) {
  const tool = TOOLS.find((t) => t.id === body.tool) || TOOLS[0];
  const message = String(body.message || '').trim();
  const cwd = body.cwd && fs.existsSync(body.cwd) ? body.cwd : HOME;
  if (!message) return { status: 400, body: { error: '空消息' } };

  // 自测假工具：不依赖任何 CLI
  if (tool.id === 'echo') {
    return new Promise((resolve) => {
      let ended = false;
      ctx.emit({ t: 'meta', cmd: 'echo', cwd });
      const reply = '收到：' + message;
      let i = 0;
      const timer = setInterval(() => {
        if (i >= reply.length) {
          clearInterval(timer);
          if (!ended) { ended = true; ctx.emit({ t: 'end', code: 0 }); resolve({ status: 200, body: { ok: true } }); }
          return;
        }
        ctx.emit({ t: 'out', d: reply.slice(i, i + 2) });
        i += 2;
      }, 20);
      ctx.setStopper(() => {
        clearInterval(timer);
        if (!ended) { ended = true; ctx.emit({ t: 'end', code: -1 }); resolve({ status: 200, body: { ok: false } }); }
      });
    });
  }

  const spec = CHAT_ARGS[tool.id];
  if (!spec) {
    ctx.emit({ t: 'err', d: '该工具暂不支持非交互调用，无法在面板中聊天。' });
    ctx.emit({ t: 'end', code: -1 });
    return { status: 200, body: { ok: false } };
  }

  const exe = commandExists(tool.cmd);
  if (!exe) {
    ctx.emit({ t: 'err', d: '未检测到命令：' + tool.cmd });
    ctx.emit({ t: 'end', code: -1 });
    return { status: 200, body: { ok: false } };
  }

  let prompt = flat(message);
  if (body.inject !== false) {
    const hint = buildHint(loadSettings());
    if (hint) prompt = flat(hint) + ' --- ' + prompt;
  }

  const args = spec(prompt);
  ctx.emit({ t: 'meta', cmd: tool.cmd + ' ' + args.slice(0, -1).join(' '), cwd });

  return new Promise((resolve) => {
    let child;
    let ended = false;
    const finish = (o) => { if (!ended) { ended = true; resolve(o); } };
    try { child = spawnTool(exe, args, cwd); }
    catch (err) {
      ctx.emit({ t: 'err', d: String((err && err.message) || err) });
      ctx.emit({ t: 'end', code: -1 });
      return finish({ status: 200, body: { ok: false } });
    }
    child.stdout.on('data', (d) => ctx.emit({ t: 'out', d: d.toString('utf8') }));
    child.stderr.on('data', (d) => ctx.emit({ t: 'err', d: d.toString('utf8') }));
    child.on('error', (err) => {
      ctx.emit({ t: 'err', d: String((err && err.message) || err) });
      ctx.emit({ t: 'end', code: -1 });
      finish({ status: 200, body: { ok: false } });
    });
    child.on('close', (code) => {
      ctx.emit({ t: 'end', code: code == null ? -1 : code });
      finish({ status: 200, body: { ok: true } });
    });
    ctx.setStopper(() => { try { child.kill(); } catch { /* ignore */ } });
  });
}

// 任务入口：{ path, method, body } → Promise<{ status, body }>
// ctx: { emit(ev), setStopper(fn) }；流式任务通过 emit 推送事件。
async function handle(job, ctx) {
  const p = (job && job.path) || '';
  const body = (job && job.body) || {};

  if (p === '/api/state') return { status: 200, body: buildState() };
  if (p === '/api/ui-state') {
    if (job.method === 'POST') {
      const cur = loadUiState();
      if (body.theme) cur.theme = String(body.theme);
      if (typeof body.cwd === 'string') cur.cwd = body.cwd;
      try { saveUiState(cur); } catch { /* ignore */ }
      return { status: 200, body: { ok: true } };
    }
    return { status: 200, body: loadUiState() };
  }
  if (p === '/api/tools') return { status: 200, body: { tools: TOOLS.map(toolInfo) } };
  if (p === '/api/current-agent') {
    const raw = currentSubagent();
    const known = agentsFromOpencode().some((a) => a.name === raw);
    return { status: 200, body: { agent: known ? raw : '', raw } };
  }
  if (p === '/api/open') return openJob(body);
  if (p === '/api/sync') return syncJob();
  if (p === '/api/chat') return chatJob(body, ctx);
  if (p === '/api/__report' && process.env.ERI_PANEL_AUTOTEST) {
    try { fs.writeFileSync(process.env.ERI_PANEL_AUTOTEST, JSON.stringify(body, null, 2)); } catch { /* ignore */ }
    return { status: 200, body: { ok: true } };
  }
  return { status: 404, body: { error: 'not found' } };
}

module.exports = { handle, buildState, TOOLS, toolInfo };
