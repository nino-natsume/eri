#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const https = require('https');
const { spawnSync } = require('child_process');

const HOME = os.homedir();
const SCRIPT_DIR = __dirname;
const PKG_DIR = '/usr/share/eri';
const DEFAULT_URL = 'https://raw.githubusercontent.com/nino-natsume/eri/main/eri.md';

let VERSION = '0.0.0';
try { VERSION = require('./package.json').version; } catch { /* ignore */ }

const h = (...a) => path.join(HOME, ...a);

const TOOLS = [
  { id: 'opencode', name: 'OpenCode', cmd: 'opencode', pdir: h('.config', 'opencode', 'agents'), pfile: 'eri.md' },
  { id: 'claude', name: 'Claude Code', cmd: 'claude', pdir: h('.claude'), pfile: 'CLAUDE.md' },
  { id: 'codex', name: 'Codex CLI (OpenAI)', cmd: 'codex', pdir: h('.codex'), pfile: 'AGENTS.md' },
  { id: 'gemini', name: 'Gemini CLI (Google)', cmd: 'gemini', pdir: h('.gemini'), pfile: 'GEMINI.md' },
  { id: 'qwen', name: 'Qwen Code (Alibaba)', cmd: 'qwen', pdir: h('.qwen'), pfile: 'GEMINI.md' },
  { id: 'aider', name: 'Aider', cmd: 'aider', pdir: h('.config', 'aider'), pfile: 'eri.md', mode: 'aider' },
  { id: 'cursor', name: 'Cursor CLI', cmd: 'cursor-agent', pdir: h('.cursor'), pfile: 'AGENTS.md' },
  { id: 'windsurf', name: 'Windsurf CLI', cmd: 'windsurf', pdir: h('.windsurf'), pfile: 'AGENTS.md' },
  { id: 'amp', name: 'Amp', cmd: 'amp', pdir: h('.amp'), pfile: 'AGENTS.md' },
  { id: 'goose', name: 'Goose (Block)', cmd: 'goose', pdir: h('.config', 'goose'), pfile: 'AGENTS.md' },
  { id: 'copilot', name: 'GitHub Copilot CLI', cmd: 'copilot', pdir: h('.github', 'copilot'), pfile: 'AGENTS.md' },
  { id: 'plandex', name: 'Plandex', cmd: 'plandex', pdir: h('.plandex'), pfile: 'AGENTS.md' },
  { id: 'tabby', name: 'Tabby', cmd: 'tabby-agent', pdir: h('.tabby'), pfile: 'AGENTS.md' },
  { id: 'fabric', name: 'Fabric', cmd: 'fabric', pdir: h('.config', 'fabric'), pfile: 'AGENTS.md' },
  { id: 'openhands', name: 'OpenHands', cmd: 'openhands', pdir: h('.openhands'), pfile: 'AGENTS.md' },
  { id: 'crush', name: 'Crush', cmd: 'crush', pdir: h('.crush'), pfile: 'AGENTS.md' },
  { id: 'devin', name: 'Devin CLI', cmd: 'devin', pdir: h('.devin'), pfile: 'AGENTS.md' },
  { id: 'continue', name: 'Continue', cmd: 'continue', pdir: h('.continue'), pfile: 'AGENTS.md' },
];

const RC_FILES = [
  h('.bashrc'), h('.bash_profile'), h('.zshrc'), h('.profile'), h('.zprofile'),
  h('.kshrc'), h('.config', 'fish', 'config.fish'), h('.tcshrc'), h('.cshrc'),
];

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

function sameContent(a, b) {
  try { return fs.readFileSync(a).equals(fs.readFileSync(b)); } catch { return false; }
}

function mkdirp(dir) { fs.mkdirSync(dir, { recursive: true }); }

function firstExisting(paths) {
  for (const p of paths) { if (fs.existsSync(p)) return p; }
  return null;
}

function ask(question) {
  return new Promise((resolve) => {
    const rl = require('readline').createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, (ans) => { rl.close(); resolve(ans); });
  });
}

function download(url, dest, depth = 0) {
  return new Promise((resolve, reject) => {
    if (depth > 5) return reject(new Error('重定向次数过多'));
    const lib = url.startsWith('https:') ? https : http;
    const req = lib.get(url, { headers: { 'User-Agent': 'eri-ai' } }, (res) => {
      const code = res.statusCode || 0;
      if ([301, 302, 303, 307, 308].includes(code) && res.headers.location) {
        res.resume();
        return resolve(download(new URL(res.headers.location, url).toString(), dest, depth + 1));
      }
      if (code !== 200) { res.resume(); return reject(new Error('HTTP ' + code)); }
      const file = fs.createWriteStream(dest);
      res.pipe(file);
      file.on('finish', () => file.close(() => resolve(dest)));
      file.on('error', reject);
    });
    req.on('error', reject);
  });
}

async function resolvePersona(rawUrl) {
  const local = firstExisting([path.join(SCRIPT_DIR, 'eri.md'), path.join(PKG_DIR, 'eri.md')]);
  const tmp = path.join(os.tmpdir(), `eri-${process.pid}-${Date.now()}.md`);
  console.log(`==> 下载人格文件: ${rawUrl}`);
  try {
    await download(rawUrl, tmp);
    return { file: tmp, cleanup: true };
  } catch (err) {
    if (local) {
      console.log(`==> 下载失败(${err.message}), 改用本地人格文件: ${local}`);
      return { file: local, cleanup: false };
    }
    throw new Error(`下载失败: ${rawUrl} (${err.message})`);
  }
}

// ------------------------------------------------------- config manipulation

function setOpenCodeDefaultAgent(cfgPath, agentName) {
  const defaultCfg = '{\n  "$schema": "https://opencode.ai/config.json",\n  "default_agent": "' + agentName + '"\n}\n';
  if (!fs.existsSync(cfgPath)) {
    fs.writeFileSync(cfgPath, defaultCfg);
    return;
  }
  let content = fs.readFileSync(cfgPath, 'utf8');
  if (/"default_agent"\s*:/.test(content)) {
    content = content.replace(/"default_agent"\s*:\s*"[^"]*"/, '"default_agent": "' + agentName + '"');
    fs.writeFileSync(cfgPath, content);
    return;
  }
  const idx = content.lastIndexOf('}');
  if (idx < 0) { fs.writeFileSync(cfgPath, defaultCfg); return; }
  let head = content.slice(0, idx).replace(/\s+$/, '');
  const tail = content.slice(idx);
  if (head.endsWith(',')) head = head.slice(0, -1).replace(/\s+$/, '');
  const result = head.endsWith('{')
    ? `${head}\n  "default_agent": "${agentName}"\n${tail}`
    : `${head},\n  "default_agent": "${agentName}"\n${tail}`;
  fs.writeFileSync(cfgPath, result);
}

function updateAiderRead(cfgPath, personaFile) {
  if (fs.existsSync(cfgPath)) {
    const content = fs.readFileSync(cfgPath, 'utf8');
    if (content.includes(personaFile)) {
      console.log('    aider read 已包含本路径,无需修改');
      return;
    }
    const lines = content.split(/\r?\n/);
    let done = false;
    const out = lines.map((ln) => {
      if (!done) {
        const m = ln.match(/^(\s*)read\s*:\s*(.*)$/);
        if (m) {
          done = true;
          const ind = m[1];
          const val = m[2].trim();
          if (val === '') return `${ln}\n${ind}  - ${personaFile}`;
          if (val.startsWith('[') && val.endsWith(']')) {
            const inner = val.slice(1, -1).trim();
            return `${ind}read: [${inner === '' ? personaFile : `${inner}, ${personaFile}`}]`;
          }
          return `read: ${val} ${personaFile}`;
        }
      }
      return ln;
    });
    if (!done) out.push(`read: ${personaFile}`);
    fs.writeFileSync(cfgPath, out.join('\n'));
  } else {
    fs.writeFileSync(cfgPath, `read: ${personaFile}\n`);
  }
}

function removeAiderRead(cfgPath, personaFile) {
  if (!fs.existsSync(cfgPath)) return;
  const content = fs.readFileSync(cfgPath, 'utf8');
  if (!content.includes(personaFile)) return;
  const lines = content.split(/\r?\n/);
  const out = [];
  for (const ln of lines) {
    if (/^\s*-\s/.test(ln) && ln.includes(personaFile)) continue;
    const m = ln.match(/^(\s*)read\s*:\s*(.*)$/);
    if (m) {
      const ind = m[1];
      const val = m[2].trim();
      if (val === '') { out.push(ln); continue; }
      if (val.startsWith('[') && val.endsWith(']')) {
        const items = val.slice(1, -1).split(',').map((s) => s.trim()).filter((s) => s && s !== personaFile);
        out.push(`${ind}read: [${items.join(', ')}]`);
        continue;
      }
      const toks = val.split(/\s+/).filter((t) => t && t !== personaFile);
      if (toks.length > 0) out.push(`${ind}read: ${toks.join(' ')}`);
      continue;
    }
    out.push(ln);
  }
  fs.writeFileSync(cfgPath, out.join('\n'));
}

function removeOpenCodeDefaultAgent(cfgPath) {
  if (!fs.existsSync(cfgPath)) return false;
  let content = fs.readFileSync(cfgPath, 'utf8');
  if (!/"default_agent"\s*:\s*"eri"/.test(content)) return false;
  // 情况 1: 独占一行的键 (含可有可无的尾逗号) -> 整行删除
  content = content.replace(/^[ \t]*"default_agent"\s*:\s*"eri"\s*,?[ \t]*(?:\r?\n|$)/gm, '');
  // 情况 2: 前导逗号 (该键在对象末尾)
  content = content.replace(/,\s*"default_agent"\s*:\s*"eri"/g, '');
  // 情况 3: 尾随逗号
  content = content.replace(/"default_agent"\s*:\s*"eri"\s*,\s*/g, '');
  // 情况 4: 单行且该键为唯一成员: {"default_agent":"eri"}
  content = content.replace(/\{\s*"default_agent"\s*:\s*"eri"\s*\}/g, '{}');
  // 情况 5: 清掉清理后遗留的悬挂逗号 (如 "a": 1,\n})
  content = content.replace(/,(\s*[}\]])/g, '$1');
  fs.writeFileSync(cfgPath, content);
  return true;
}

// ----------------------------------------------------------- persona deploy

function deployPersona(tool, srcFile) {
  mkdirp(tool.pdir);
  const target = path.join(tool.pdir, tool.pfile);

  if (fs.existsSync(target) && !fs.existsSync(target + '.bak') && !sameContent(srcFile, target)) {
    fs.copyFileSync(target, target + '.bak');
    console.log(`  备份旧文件: ${target}.bak`);
  }
  fs.copyFileSync(srcFile, target);
  console.log(`  updated: ${target}`);

  if (tool.mode === 'aider') {
    updateAiderRead(h('.aider.conf.yml'), target);
  }
  if (tool.id === 'opencode') {
    const cfg = path.join(path.dirname(tool.pdir), 'opencode.jsonc');
    setOpenCodeDefaultAgent(cfg, path.basename(tool.pfile, '.md'));
    console.log(`    opencode.jsonc: default_agent = ${path.basename(tool.pfile, '.md')}`);
  }
}

function installedTools() {
  return TOOLS.filter((t) => commandExists(t.cmd));
}

// ------------------------------------------------------------ deep integrate

function deepSrc() {
  for (const d of [PKG_DIR, SCRIPT_DIR]) {
    if (fs.existsSync(path.join(d, 'personality.json'))) return d;
  }
  return null;
}

function deepPick(dir, rel, flat) {
  const relPath = path.join(dir, rel);
  if (fs.existsSync(relPath)) return relPath;
  const flatPath = path.join(dir, flat);
  if (fs.existsSync(flatPath)) return flatPath;
  return null;
}

async function deployDeep() {
  const src = deepSrc();
  if (!src) {
    console.error('==> 错误：未找到深度部署资源(personality.json)');
    return false;
  }
  const cfg = h('.config', 'opencode');
  mkdirp(path.join(cfg, 'agent'));
  mkdirp(path.join(cfg, 'skill', 'eri'));

  fs.copyFileSync(path.join(src, 'personality.json'), path.join(cfg, 'personality.json'));
  console.log(`==> personality.json -> ${path.join(cfg, 'personality.json')}`);

  for (const a of ['erotic-chan', 'code-monkey', 'debug-san', 'architect-sama', 'test-chan']) {
    const f = deepPick(src, path.join('agent', `${a}.md`), `${a}.md`);
    if (f) {
      fs.copyFileSync(f, path.join(cfg, 'agent', `${a}.md`));
      console.log(`==> agent/${a}.md -> ${path.join(cfg, 'agent', `${a}.md`)}`);
    } else {
      console.warn(`==> 警告：缺少子智慧体 ${a}.md,已跳过`);
    }
  }

  const skill = deepPick(src, path.join('skill', 'eri', 'SKILL.md'), 'SKILL.md');
  if (skill) {
    fs.copyFileSync(skill, path.join(cfg, 'skill', 'eri', 'SKILL.md'));
    console.log(`==> SKILL.md -> ${path.join(cfg, 'skill', 'eri', 'SKILL.md')}`);
  } else {
    console.warn('==> 警告：缺少 SKILL.md,skill 不可用');
  }

  let oc = path.join(cfg, 'opencode.jsonc');
  if (!fs.existsSync(oc) && fs.existsSync(path.join(cfg, 'opencode.json'))) {
    oc = path.join(cfg, 'opencode.json');
  }
  if (!fs.existsSync(oc)) {
    fs.copyFileSync(path.join(src, 'opencode.json'), path.join(cfg, 'opencode.jsonc'));
    console.log(`==> opencode.json -> ${path.join(cfg, 'opencode.jsonc')}`);
  } else {
    const content = fs.readFileSync(oc, 'utf8');
    if (/"plugin"/.test(content)) {
      console.log(`==> 已有 opencode 配置含深度集成字段,跳过模板写入: ${oc}`);
    } else {
      let writeTpl = true;
      if (process.stdin.isTTY) {
        const ans = await ask('已有 opencode 配置缺少 plugin/skills 等深度字段,是否备份后用模板覆盖? [Y/n] ');
        if (ans === 'n' || ans === 'N') writeTpl = false;
      }
      if (writeTpl) {
        if (!fs.existsSync(oc + '.bak')) {
          fs.copyFileSync(oc, oc + '.bak');
          console.log(`==> 备份旧配置: ${oc}.bak`);
        }
        const m = content.match(/"default_agent"\s*:\s*"([^"]*)"/);
        fs.copyFileSync(path.join(src, 'opencode.json'), oc);
        console.log(`==> 深度配置已写入: ${oc} (旧配置在 .bak)`);
        if (m) {
          setOpenCodeDefaultAgent(oc, m[1]);
          console.log(`==> 已保留原 default_agent = ${m[1]}`);
        }
      } else {
        console.log(`注意：请手动合并 ${path.join(src, 'opencode.json')} 中的 plugin/agent/skills/command 字段到 ${oc}`);
      }
    }
  }

  const srcManifest = path.join(src, 'opencode-package.json');
  if (fs.existsSync(srcManifest) && !fs.existsSync(path.join(cfg, 'package.json'))) {
    fs.copyFileSync(srcManifest, path.join(cfg, 'package.json'));
    console.log(`==> package.json (OpenCode 依赖清单) -> ${path.join(cfg, 'package.json')}`);
  }
  const srcLock = path.join(src, 'opencode-package-lock.json');
  if (fs.existsSync(srcLock) && !fs.existsSync(path.join(cfg, 'package-lock.json'))) {
    fs.copyFileSync(srcLock, path.join(cfg, 'package-lock.json'));
    console.log(`==> package-lock.json -> ${path.join(cfg, 'package-lock.json')}`);
  }

  if (!commandExists('npm')) {
    console.error('==> 错误：未找到 npm,请先安装 Node.js/npm 后重试');
    return false;
  }
  console.log(`==> 在 ${cfg} 执行 npm install ...`);
  const npmArgs = ['install', '--no-audit', '--no-fund'];
  const r = process.platform === 'win32'
    ? spawnSync(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', 'npm.cmd ' + npmArgs.join(' ')], { cwd: cfg, encoding: 'utf8' })
    : spawnSync('npm', npmArgs, { cwd: cfg, encoding: 'utf8' });
  if (r.stdout) process.stdout.write(r.stdout);
  if (r.stderr) process.stderr.write(r.stderr);
  if (r.status !== 0) {
    console.error('==> 错误：npm install 失败,请检查网络后在配置目录下重试');
    return false;
  }

  console.log('==> OpenCode 深度部署完成！重启 opencode 生效。');
  console.log('    之后可用 /personality 管理人格, /force-chat 与 /force-work 切换模式, /mood 设置心情。');
  return true;
}

// ----------------------------------------------------------------- commands

function showHelp() {
  console.log(`eri - 绘里酱人格管理工具 (v${VERSION})

用法:
  eri update [RAW_URL]    更新人格到所有已安装的终端工具 (默认命令)
  eri deep                部署 OpenCode 深度集成 (skill + 5 子智慧体 + personality 插件 + mood)
  eri ui [--no-open]      启动可视化管理面板 (读取当前设定, 复用已装 CLI 聊天)
  eri uninstall [--yes]   卸载所有已部署的人格文件 (不带 --yes 时交互式二次确认)
  eri help                显示帮助
  eri version             显示版本
  eri <RAW_URL>           兼容简写, 等价于 eri update <RAW_URL>

环境变量:
  ERI_URL                 自定义人格文件 URL
  ERI_PANEL_PORT          管理面板监听端口 (默认 8710)

常见问题:
  若提示 'eri' 不是命令, 请确认已全局安装 (npm i -g eri-ai), 或打开新终端。`);
}

async function doUpdate(rawUrl) {
  const { file, cleanup } = await resolvePersona(rawUrl);
  const tools = installedTools();
  if (tools.length === 0) {
    console.error('==> 未检测到任何已安装的终端工具');
    if (cleanup) fs.rmSync(file, { force: true });
    process.exitCode = 1;
    return;
  }
  let count = 0;
  for (const tool of tools) {
    try {
      deployPersona(tool, file);
      count++;
    } catch (err) {
      console.error(`==> 部署失败 ${tool.name}: ${err.message}`);
    }
  }
  if (cleanup) fs.rmSync(file, { force: true });
  console.log(`==> 已更新 ${count} 个工具的人格文件, 重启对应工具生效♡`);
}

async function doUninstall(args) {
  const yes = args.includes('--yes') || args.includes('-y') || args.includes('-yes');
  console.log('==> 绘里酱人格卸载\n');
  console.log('将执行以下操作:');
  console.log('  • 删除/恢复各工具的人格文件 (如 .bak 存在则恢复备份)');
  console.log('  • 清理 OpenCode default_agent 与 aider read 配置');
  console.log('  • 从 shell 配置中移除本工具添加的 PATH 行\n');

  if (!yes) {
    if (!process.stdin.isTTY) {
      console.error('==> 非交互模式, 如需静默卸载请加 --yes (eri uninstall --yes)');
      process.exitCode = 1;
      return;
    }
    const ans = await ask('确认卸载? [y/N] ');
    if (ans !== 'y' && ans !== 'Y') {
      console.log('==> 已取消');
      return;
    }
  }

  for (const tool of TOOLS) {
    const target = path.join(tool.pdir, tool.pfile);
    if (!fs.existsSync(target)) continue;
    if (fs.existsSync(target + '.bak')) {
      fs.rmSync(target, { force: true });
      fs.renameSync(target + '.bak', target);
      console.log(`  已恢复: ${target} (来自备份)`);
    } else {
      fs.rmSync(target, { force: true });
      console.log(`  已删除: ${target}`);
    }
  }

  const aiderCfg = h('.aider.conf.yml');
  if (fs.existsSync(aiderCfg + '.bak')) {
    fs.rmSync(aiderCfg, { force: true });
    fs.renameSync(aiderCfg + '.bak', aiderCfg);
    console.log(`  已恢复: ${aiderCfg} (来自备份)`);
  }
  const myAiderPath = h('.config', 'aider', 'eri.md');
  if (fs.existsSync(aiderCfg)) {
    const before = fs.readFileSync(aiderCfg, 'utf8');
    removeAiderRead(aiderCfg, myAiderPath);
    if (fs.readFileSync(aiderCfg, 'utf8') !== before) {
      console.log(`  已清理: ${aiderCfg} (移除本工具的 read 路径)`);
    }
  }

  for (const name of ['opencode.jsonc', 'opencode.json']) {
    const cfg = h('.config', 'opencode', name);
    if (fs.existsSync(cfg + '.bak')) {
      fs.rmSync(cfg, { force: true });
      fs.renameSync(cfg + '.bak', cfg);
      console.log(`  已恢复: ${cfg} (来自备份)`);
    }
    if (removeOpenCodeDefaultAgent(cfg)) {
      console.log(`  已清理: ${cfg} (移除 default_agent)`);
    }
  }

  for (const rc of RC_FILES) {
    if (!fs.existsSync(rc)) continue;
    const lines = fs.readFileSync(rc, 'utf8').split(/\r?\n/);
    let changed = false;
    const out = [];
    for (let i = 0; i < lines.length; i++) {
      if (lines[i] === '# eri: ensure ~/.local/bin in PATH') {
        i++;
        changed = true;
        continue;
      }
      out.push(lines[i]);
    }
    if (changed) {
      fs.writeFileSync(rc, out.join('\n'));
      console.log(`  已清理 PATH: ${rc}`);
    }
  }

  const localEri = h('.local', 'bin', 'eri');
  try {
    if (fs.existsSync(localEri) && fs.realpathSync(localEri) !== fs.realpathSync(__filename)) {
      fs.rmSync(localEri, { force: true });
      fs.rmSync(localEri + '.bak', { force: true });
      console.log(`  已删除: ${localEri}`);
    }
  } catch { /* ignore */ }

  if (fs.existsSync(h('.config', 'opencode', 'personality.json'))) {
    console.log('\n  提示: OpenCode 深度集成文件仍保留, 未自动移除:');
    console.log('    ~/.config/opencode/personality.json');
    console.log('    ~/.config/opencode/skill/eri/  ~/.config/opencode/agent/  ~/.config/opencode/package.json');
    console.log('    如需彻底移除, 删除上述文件/目录, 并从 opencode.jsonc 中移除 plugin/skills/agent/command 字段');
  }

  console.log('\n==> 卸载完成! 新开终端生效♡');
}

// --------------------------------------------------------------------- main

async function main() {
  const args = process.argv.slice(2);
  let sub = args[0] || 'update';

  switch (sub) {
    case 'help':
    case '-h':
    case '--help':
      showHelp();
      return;
    case 'version':
    case '-v':
    case '-V':
    case '--version':
      console.log(VERSION);
      return;
    case 'deep':
      await deployDeep();
      return;
    case 'ui':
    case 'panel': {
      const panelPath = path.join(SCRIPT_DIR, 'ui', 'panel.js');
      if (!fs.existsSync(panelPath)) {
        console.error('==> 错误：未找到面板文件 ui/panel.js');
        process.exitCode = 1;
        return;
      }
      const r = spawnSync(process.execPath, [panelPath, ...args.slice(1)], { stdio: 'inherit' });
      process.exitCode = r.status || 0;
      return;
    }
    case 'uninstall':
    case 'remove':
    case 'rm':
      await doUninstall(args.slice(1));
      return;
    case 'update':
      args.shift();
      break;
    default:
      break;
  }

  let rawUrl = args[0] || process.env.ERI_URL || DEFAULT_URL;
  await doUpdate(rawUrl);
}

main().catch((err) => {
  console.error(`==> ${err.message}`);
  process.exitCode = 1;
});
