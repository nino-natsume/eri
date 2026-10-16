'use strict';
// 面板前端（内嵌为字符串，便于 Bun 编译成单文件 exe）。
// 风格: 樱花粉主题 #ffb7c5 / 毛玻璃卡片 / Inter 字体栈 / 深浅色切换。
// 通信: 无端口 —— 经窗口桥 window.eriNative（webview_bind）提交任务 + 轮询结果。

const PAGE = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>绘里酱</title>
<link rel="icon" href="data:image/png;base64,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">
<style>
:root{
  --bg-primary:#ffffff;
  --bg-secondary:rgba(255,255,255,0.95);
  --text-primary:#1f2937;
  --text-secondary:#666;
  --text-muted:#9ca3af;
  --border-color:#e5e7eb;
  --input-bg:#ffffff;
  --input-border:#e5e7eb;
  --admin-bg-base:#f8fafc;
  --card-bg:rgba(255,255,255,0.95);
  --card-bg-soft:#f9fafb;
  --accent-a:#ffb7c5;
  --accent-b:#ff9cba;
  --shadow-card:0 10px 30px rgba(15,23,42,0.08), 0 2px 8px rgba(15,23,42,0.05);
}
html.dark-mode{
  --bg-primary:#1a1a1a;
  --bg-secondary:#0f0d0a;
  --text-primary:#e5e5e5;
  --text-secondary:#a0a0a0;
  --text-muted:#8a8a8a;
  --border-color:#333333;
  --input-bg:#2a2a2a;
  --input-border:#444444;
  --admin-bg-base:#070b12;
  --card-bg:rgba(39,39,39,0.95);
  --card-bg-soft:#232323;
  --shadow-card:0 10px 30px rgba(0,0,0,0.35), 0 2px 8px rgba(0,0,0,0.25);
}
*{margin:0;padding:0;box-sizing:border-box}
html,body{height:100%}
body{
  font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
  color:var(--text-primary);
  background:var(--admin-bg-base);
  overflow:hidden;
}
#app{display:flex;flex-direction:column;height:100vh;padding:14px 16px 16px;gap:12px}

/* 顶栏（edgetunnel header 风格：顶部橙色渐变描边） */
header{
  display:flex;justify-content:space-between;align-items:center;gap:14px;
  background:var(--card-bg);
  -webkit-backdrop-filter:blur(20px);backdrop-filter:blur(20px);
  padding:14px 22px;border-radius:16px;
  border-top:4px solid;border-image:linear-gradient(90deg,#ffb7c5 0,#ff9cba 50%,#ffb7c5 100%) 1;
  box-shadow:var(--shadow-card);
}
.brand{display:flex;align-items:center;gap:9px;font-size:19px;font-weight:700;letter-spacing:-0.3px;
  background:linear-gradient(135deg,#ffb7c5 0,#ee6f9b 100%);
  -webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.logo{width:32px;height:32px;border-radius:9px;object-fit:cover;flex:none}
.meta{display:flex;align-items:center;gap:12px;color:var(--text-secondary);font-size:12.5px}
.badge{
  display:inline-flex;align-items:center;justify-content:center;
  min-width:86px;height:34px;padding:0 12px;font-size:12.5px;font-weight:600;letter-spacing:.2px;
  color:var(--text-secondary);
  background:var(--card-bg-soft);
  border:1px solid var(--border-color);border-radius:10px;
}
.dot{width:9px;height:9px;border-radius:50%;background:#ef4444;display:inline-block;transition:background .3s ease}
.dot.on{background:#10b981}
.icon-btn{
  width:38px;height:38px;display:inline-flex;align-items:center;justify-content:center;
  background:var(--card-bg-soft);border:1px solid var(--border-color);border-radius:10px;
  color:var(--text-secondary);cursor:pointer;transition:all .3s ease;
}
.icon-btn:hover{transform:translateY(-1px);border-color:rgba(255,183,197,.55);color:#ee6f9b;
  box-shadow:0 8px 24px rgba(255,183,197,.3),0 4px 12px rgba(255,156,186,.18)}
.icon-btn svg{width:19px;height:19px}
html.dark-mode .icon-btn:hover{color:#ffb7c5}
.moon{display:none}
html.dark-mode .sun{display:none}
html.dark-mode .moon{display:inline}

main{display:flex;flex:1;min-height:0;gap:12px}
aside{width:300px;min-width:300px;display:flex;flex-direction:column;gap:12px;overflow:auto;padding-right:2px}
.module{
  background:var(--card-bg);
  -webkit-backdrop-filter:blur(20px);backdrop-filter:blur(20px);
  border-radius:16px;padding:16px 18px;
  box-shadow:4px 4px 8px -3px rgba(0,0,0,.12);
}
html.dark-mode .module{box-shadow:4px 4px 8px -3px rgba(0,0,0,.4)}
.module h3{font-size:13px;font-weight:700;color:var(--text-secondary);margin:0 0 10px;letter-spacing:.3px}
label{display:block;margin:0 0 6px;color:var(--text-primary);font-size:12.5px;font-weight:600}
select,input[type=text],textarea{
  width:100%;font:inherit;font-size:13.5px;padding:9px 12px;color:var(--text-primary);
  background:var(--input-bg);
  border:2px solid var(--input-border);border-radius:12px;
  transition:all .3s ease;-webkit-appearance:none;appearance:none;
}
select:focus,input[type=text]:focus,textarea:focus{
  outline:0;border-color:var(--accent-a);
  box-shadow:0 0 0 4px rgba(255,183,197,.18);
}
html.dark-mode select:focus,html.dark-mode input[type=text]:focus,html.dark-mode textarea:focus{
  border-color:#ffb7c5;box-shadow:0 0 0 4px rgba(255,183,197,.15);
}
.btn{
  padding:8px 16px;border:0;border-radius:12px;font:inherit;font-size:13.5px;font-weight:600;
  cursor:pointer;letter-spacing:.4px;transition:all .3s ease;
}
.btn-primary{background:linear-gradient(135deg,#ffb7c5 0,#ff9cba 100%);color:#7d2c46;
  box-shadow:0 4px 15px rgba(255,183,197,.25)}
.btn-primary:hover:enabled{transform:translateY(-2px);box-shadow:0 6px 25px rgba(255,183,197,.4)}
.btn-secondary{background:#e5e7eb;color:#374151}
html.dark-mode .btn-secondary{background:#333;color:#e5e5e5}
.btn-secondary:hover:enabled{background:#d1d5db}
html.dark-mode .btn-secondary:hover:enabled{background:#3f3f3f}
.btn:disabled{opacity:.5;cursor:not-allowed}
.btn:active:enabled{transform:translateY(0)}
.row{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-top:9px}
.hint{color:var(--text-muted);font-size:12px}
.kv{font-size:15px;color:var(--text-secondary);line-height:1.5}
.kv b{color:var(--text-primary);font-weight:700}
.kv + .kv{margin-top:8px}
.chk{display:flex;align-items:center;gap:7px;margin-top:9px;color:var(--text-primary);font-size:12.5px;font-weight:600}
.chk input{width:auto;accent-color:#ffb7c5}
#out{margin:9px 0 0;padding:9px 11px;max-height:130px;overflow:auto;
  background:var(--card-bg-soft);border:1px solid var(--border-color);border-radius:10px;
  white-space:pre-wrap;font:12px/1.5 Consolas,'Courier New',monospace;color:var(--text-secondary);display:none}

.chat{
  flex:1;min-width:0;display:flex;flex-direction:column;
  background:var(--card-bg);
  -webkit-backdrop-filter:blur(20px);backdrop-filter:blur(20px);
  border-radius:16px;box-shadow:var(--shadow-card);overflow:hidden;
}
#log{flex:1;overflow:auto;padding:16px 18px}
.msg{margin:0 0 14px;max-width:88%}
.msg .who{font-size:11.5px;color:var(--text-muted);margin-bottom:4px;font-weight:600;letter-spacing:.3px}
.msg .body{white-space:pre-wrap;word-break:break-word;font-size:13.5px;line-height:1.6;
  border-radius:12px;padding:10px 13px}
.msg.user{margin-left:auto}
.msg.user .who{text-align:right}
.msg.user .body{background:linear-gradient(135deg,rgba(255,183,197,.18),rgba(255,156,186,.14));
  border:1px solid rgba(255,183,197,.4)}
.msg.assistant .body{background:var(--bg-primary);border:1px solid var(--border-color);color:var(--text-primary)}
html.dark-mode .msg.assistant .body{background:var(--card-bg-soft)}
.msg.err .body{background:#fdf3f3;border:1px solid #edcccc;color:#8a2f2f}
html.dark-mode .msg.err .body{background:#3a2020;border-color:#5c3131;color:#f0b9b9}
.meta-line{color:var(--text-muted);font-size:11.5px;margin:-8px 0 12px}
.compose{border-top:1px solid var(--border-color);padding:12px 14px;background:var(--card-bg-soft)}
.compose textarea{height:72px;resize:vertical;font-size:13.5px}
.send{display:flex;justify-content:flex-end;gap:8px;margin-top:8px}

#toasts{position:fixed;top:18px;right:18px;z-index:9000;display:flex;flex-direction:column;gap:8px}
.toast{
  padding:11px 18px;border-radius:10px;color:#fff;font-size:13px;font-weight:500;max-width:320px;
  box-shadow:0 8px 24px rgba(0,0,0,.18);transform:translateX(120%);opacity:0;
  transition:transform .3s ease,opacity .3s ease;
}
.toast.show{transform:translateX(0);opacity:1}
.toast-success{background:linear-gradient(135deg,#10b981 0,#059669 100%)}
.toast-error{background:linear-gradient(135deg,#ef4444 0,#dc2626 100%)}
.toast-info{background:linear-gradient(135deg,#3b82f6 0,#1d4ed8 100%)}
</style>
</head>
<body>
<div id="app">
  <header>
    <div class="brand"><img class="logo" src="https://img.107211.xyz/file/img/2U6pYCWK.webp" alt="" onerror="if(!this.__f){this.__f=1;this.src='data:image/png;base64,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'}else{this.style.display='none'}">绘里酱</div>
    <div class="meta">
      <span id="src"></span>
      <span id="ver" class="badge"></span>
      <span id="dot" class="dot"></span>
      <span id="status">未连接</span>
      <button class="icon-btn" id="themeToggle" title="切换日间/夜间模式">
        <svg class="sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>
        <svg class="moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>
      </button>
    </div>
  </header>
  <main>
    <aside>
      <section class="module">
        <h3>终端工具（聊天后端）</h3>
        <select id="tool"></select>
        <div class="row">
          <button id="refresh" class="btn btn-secondary">刷新检测</button>
          <span id="toolstate" class="hint"></span>
        </div>
      </section>
      <section class="module">
        <h3>工作目录</h3>
        <input id="cwd" type="text" spellcheck="false" />
      </section>
      <section class="module">
        <h3>当前人格</h3>
        <div class="kv">人格：<b id="activeName">-</b></div>
        <div class="kv">心情：<b id="activeMood">-</b></div>
        <div class="kv">子智慧体：<b id="activeAgent">-</b></div>
        <label class="chk"><input type="checkbox" id="inject" checked /> 发送时注入当前人格 / 心情</label>
      </section>
      <section class="module">
        <h3>其它</h3>
        <div class="row">
          <button id="opencfg" class="btn btn-secondary">打开配置目录</button>
          <button id="sync" class="btn btn-secondary">同步人格到已装工具</button>
        </div>
        <pre id="out"></pre>
      </section>
    </aside>
    <div class="chat">
      <div id="log"></div>
      <div class="compose">
        <textarea id="msg" placeholder="输入消息；Enter 发送，Shift+Enter 换行"></textarea>
        <div class="send">
          <button id="stop" class="btn btn-secondary" disabled>停止</button>
          <button id="send" class="btn btn-primary">发送</button>
        </div>
      </div>
    </div>
  </main>
</div>
<div id="toasts"></div>
<script>
(function(){
  var state = null, busy = false, stopping = false, chatSid = null;

  function el(id){ return document.getElementById(id); }
  function setStatus(t, ok){
    el('status').textContent = t;
    el('dot').className = 'dot' + (ok ? ' on' : '');
  }
  function toast(type, text){
    var box = el('toasts');
    var d = document.createElement('div');
    d.className = 'toast toast-' + type;
    d.textContent = text;
    box.appendChild(d);
    setTimeout(function(){ d.classList.add('show'); }, 16);
    setTimeout(function(){
      d.classList.remove('show');
      setTimeout(function(){ if (d.parentNode) d.parentNode.removeChild(d); }, 320);
    }, 3200);
  }

  /* ---- 窗口桥：提交任务 + 轮询结果（无端口） ---- */
  var bridgeOk = typeof window.eriNative === 'function';
  function nativeCall(obj){
    if (!bridgeOk) return Promise.reject(new Error('窗口桥不可用'));
    var p;
    try { p = window.eriNative(JSON.stringify(obj)); }
    catch (e) { return Promise.reject(e); }
    return p.then(function(r){
      /* 桥的回包可能已是对象（wry 会先 JSON.parse），兼容字符串形态 */
      if (typeof r === 'string') { try { return JSON.parse(r); } catch (e) { return r; } }
      return r;
    });
  }
  var pending = {}, pollTimer = null, pollSeq = 0;
  function pendingCount(){ for (var k in pending) { if (Object.prototype.hasOwnProperty.call(pending, k)) return 1; } return 0; }
  function stopPoll(){ if (pollTimer) { clearInterval(pollTimer); pollTimer = null; } }
  function ensurePoll(){
    if (pollTimer) return;
    pollTimer = setInterval(pollOnce, 60);
    pollOnce();
  }
  function pollOnce(){
    var n = ++pollSeq;
    nativeCall({ op: 'poll' }).then(function(r){
      if (n !== pollSeq && false) return; /* 允许并发安全：直接处理 */
      var msgs = (r && r.msgs) || [];
      for (var i = 0; i < msgs.length; i++) handleMsg(msgs[i]);
      if (!pendingCount()) stopPoll();
    }).catch(function(){ /* 窗口关闭等 */ });
  }
  function handleMsg(m){
    if (!m) return;
    var p = pending[m.sid];
    if (!p) return;
    if (m.t === 'ev') { if (p.onEvent) { try { p.onEvent(m.ev || {}); } catch(e){ /* ignore */ } } return; }
    delete pending[m.sid];
    if (m.t === 'result'){
      var body = m.body || {};
      if (m.status >= 400) p.reject(new Error(body.error || ('status ' + m.status)));
      else p.resolve(body);
    } else if (m.t === 'error') {
      p.reject(new Error(m.error || '任务失败'));
    }
  }
  function invoke(path, method, body, onEvent){
    var opts = { op: 'submit', path: path, method: method || (body === undefined ? 'GET' : 'POST'), body: body || {} };
    return nativeCall(opts).then(function(r){
      if (!r || !r.ok) throw new Error((r && r.error) || '提交失败');
      var sid = r.sid;
      return new Promise(function(resolve, reject){
        pending[sid] = { onEvent: onEvent, resolve: resolve, reject: reject };
        if (path === '/api/chat') chatSid = sid;
        ensurePoll();
      });
    });
  }

  /* ---- 主题（edgetunnel 同款机制 + 服务端持久化：窗口内 localStorage 可能不可用） ---- */
  function applyTheme(t){ document.documentElement.classList.toggle('dark-mode', t === 'dark'); }
  var theme = null;
  try { theme = localStorage.getItem('theme'); } catch(e){ /* ignore */ }
  if (!theme) theme = (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) ? 'dark' : 'light';
  applyTheme(theme);
  function saveTheme(t){
    try { localStorage.setItem('theme', t); } catch(e){ /* ignore */ }
    invoke('/api/ui-state', 'POST', { theme: t }).catch(function(){ /* ignore */ });
  }
  el('themeToggle').onclick = function(){
    var next = document.documentElement.classList.contains('dark-mode') ? 'light' : 'dark';
    applyTheme(next);
    saveTheme(next);
  };
  var uiState = {};
  invoke('/api/ui-state').then(function(s){
    if (!s) return;
    uiState = s;
    if (uiState.theme === 'dark' || uiState.theme === 'light') applyTheme(uiState.theme);
    if (uiState.cwd) el('cwd').value = uiState.cwd;
  }).catch(function(){ /* ignore */ });

  function curTool(){ var id = el('tool').value; return (state.tools||[]).filter(function(t){ return t.id === id; })[0]; }

  function fillTools(){
    var sel = el('tool'); sel.innerHTML = '';
    (state.tools||[]).forEach(function(t){
      var o = document.createElement('option');
      o.value = t.id;
      o.textContent = t.name + (t.installed ? (t.supported ? '' : '（不支持聊天）') : '（未安装）');
      sel.appendChild(o);
    });
    var first = (state.tools||[]).filter(function(t){ return t.installed && t.supported; })[0];
    if (first) sel.value = first.id;
    onToolChange();
  }
  function onToolChange(){
    var t = curTool();
    var ok = !!(t && t.installed && t.supported);
    el('send').disabled = !ok || busy;
    el('toolstate').textContent = !t ? '' : (t.installed ? (t.supported ? '已就绪' : '该工具不支持非交互聊天') : '未检测到命令 ' + t.cmd);
  }
  function setActiveAgent(name){
    var v = name || '未使用';
    var b = el('activeAgent');
    if (b.textContent !== v) b.textContent = v;
  }
  function scrollDown(){ var l = el('log'); l.scrollTop = l.scrollHeight; }
  function addMsg(who, cls){
    var d = document.createElement('div'); d.className = 'msg ' + cls;
    var w = document.createElement('div'); w.className = 'who'; w.textContent = who;
    var b = document.createElement('div'); b.className = 'body';
    d.appendChild(w); d.appendChild(b); el('log').appendChild(d); scrollDown();
    return b;
  }
  function addMeta(text){
    var d = document.createElement('div'); d.className = 'meta-line'; d.textContent = text;
    el('log').appendChild(d); scrollDown();
  }
  function showOut(text){ var o = el('out'); o.style.display = 'block'; o.textContent = text; }

  function boot(){
    invoke('/api/state').then(function(s){
      state = s;
      el('ver').textContent = 'v' + s.version;
      el('src').textContent = '设置：' + s.settingsSource;
      el('cwd').value = uiState.cwd || s.home || '';
      el('activeName').textContent = s.active || '-';
      var ap = (s.personalities || []).filter(function(x){ return x.name === s.active; })[0];
      el('activeMood').textContent = (ap && (ap.moodOverride || ap.moodDefault)) || '默认（随机调度）';
      setActiveAgent(s.currentAgent);
      fillTools();
      setStatus('就绪', true);
    }).catch(function(e){
      setStatus('读取失败', false);
      toast('error', '读取面板状态失败' + (e && e.message ? '：' + e.message : ''));
    });
  }

  function send(){
    if (busy) return;
    var t = curTool();
    if (!t || !t.installed || !t.supported) return;
    var msg = el('msg').value.trim();
    if (!msg) return;
    addMsg('你', 'user').textContent = msg;
    el('msg').value = '';
    var ab = addMsg(t.name, 'assistant');
    busy = true; stopping = false; el('send').disabled = true; el('stop').disabled = false;
    setStatus('生成中…', true);
    invoke('/api/chat', 'POST',
      { tool: t.id, message: msg, cwd: el('cwd').value.trim(), inject: el('inject').checked },
      function(o){
        if (o.t === 'meta') addMeta('· ' + o.cmd + '  @ ' + o.cwd);
        else if (o.t === 'out') { ab.textContent += o.d; scrollDown(); }
        else if (o.t === 'err') { ab.parentNode.className = 'msg err'; ab.textContent += o.d; scrollDown(); }
        else if (o.t === 'end' && o.code !== 0 && !stopping) addMeta('· 退出码 ' + o.code);
      }
    ).catch(function(e){
      ab.parentNode.className = 'msg err';
      ab.textContent += String((e && e.message) || e);
    }).then(function(){
      busy = false; stopping = false; chatSid = null;
      el('stop').disabled = true; onToolChange(); setStatus('就绪', true);
      if (!ab.textContent) ab.textContent = '（无输出）';
    });
  }

  el('refresh').onclick = function(){
    invoke('/api/tools').then(function(r){ state.tools = r.tools; fillTools(); toast('info', '已刷新工具检测'); })
      .catch(function(e){ toast('error', '刷新失败：' + ((e && e.message) || e)); });
  };
  el('tool').onchange = onToolChange;
  el('cwd').addEventListener('change', function(){
    var v = el('cwd').value.trim();
    uiState.cwd = v;
    invoke('/api/ui-state', 'POST', { cwd: v }).catch(function(){ /* ignore */ });
  });
  el('opencfg').onclick = function(){
    invoke('/api/open', 'POST', {}).then(function(){ showOut('已在文件管理器中打开配置目录'); toast('info', '已打开配置目录'); })
      .catch(function(e){ toast('error', '打开失败：' + ((e && e.message) || e)); });
  };
  el('sync').onclick = function(){
    showOut('正在执行 eri update ...');
    invoke('/api/sync', 'POST', {}).then(function(r){
      if (r.error) { showOut('失败：' + r.error); toast('error', '同步失败：' + r.error); }
      else { showOut(r.out || ('退出码 ' + r.code)); toast(r.ok ? 'success' : 'error', r.ok ? '人格已同步' : ('同步退出码 ' + r.code)); }
    }).catch(function(e){ showOut('失败：' + ((e && e.message) || e)); toast('error', '同步失败：' + ((e && e.message) || e)); });
  };
  el('send').onclick = send;
  el('stop').onclick = function(){
    if (!busy) return;
    stopping = true; el('stop').disabled = true;
    addMeta('· 已停止');
    if (chatSid) nativeCall({ op: 'stop', sid: chatSid }).catch(function(){ /* ignore */ });
    else { busy = false; onToolChange(); setStatus('就绪', true); }
  };
  el('msg').addEventListener('keydown', function(e){
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
  });

  /* ---- 自测钩子：ERI_PANEL_AUTOTEST 时走真实 UI 路径做端到端检查，写报告并关窗 ---- */
  function autotest(){
    var t0 = Date.now();
    function report(obj){
      invoke('/api/__report', 'POST', obj).catch(function(){ /* ignore */ }).then(function(){
        nativeCall({ op: 'close' }).catch(function(){ /* ignore */ });
      });
    }
    function finish(){
      var bodies = el('log').querySelectorAll('.msg.assistant .body');
      var txt = bodies.length ? bodies[bodies.length - 1].textContent : '';
      report({
        ok: txt === '收到：自测',
        version: state && state.version,
        chat: txt,
        domMsgs: el('log').children.length,
        theme: document.documentElement.className,
        agent: el('activeAgent').textContent,
      });
    }
    function waitDone(){
      if (busy) {
        if (Date.now() - t0 > 15000) { report({ ok: false, error: 'chat timeout' }); return; }
        setTimeout(waitDone, 100);
        return;
      }
      finish();
    }
    function stepChat(){
      el('msg').value = '自测';
      el('send').click();
      setTimeout(waitDone, 150);
    }
    function waitBooted(){
      if (state) { stepChat(); return; }
      if (Date.now() - t0 > 15000) { report({ ok: false, error: 'boot timeout' }); return; }
      setTimeout(waitBooted, 100);
    }
    waitBooted();
  }

  boot();
  /* 子智慧体跟随 opencode 运行状态（只读、自动切换） */
  setInterval(function(){
    invoke('/api/current-agent').then(function(r){ setActiveAgent(r && r.agent); })
      .catch(function(){ /* ignore */ });
  }, 5000);
  if (window.__ERI_AUTOTEST__) autotest();
})();
</script>
</body>
</html>
`;

module.exports = PAGE;
