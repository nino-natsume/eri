'use strict';
// 面板前端（内嵌为字符串，便于 Bun 编译成单文件 exe）。
// 桌面工具风格：系统字体 / 灰白配色 / 无渐变，力求“无 AI 味”。

const PAGE = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>绘里酱 管理面板</title>
<style>
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;font:13px/1.5 "Segoe UI",system-ui,-apple-system,"Microsoft YaHei","PingFang SC",sans-serif;color:#2b2b2b;background:#ececec}
#app{display:flex;flex-direction:column;height:100vh}
header{display:flex;justify-content:space-between;align-items:center;gap:12px;padding:7px 12px;background:#f7f7f7;border-bottom:1px solid #cfcfcf}
.brand{font-weight:600;font-size:13px}
.meta{display:flex;align-items:center;gap:8px;color:#666;font-size:12px}
.dot{width:8px;height:8px;border-radius:50%;background:#c33;display:inline-block}
.dot.on{background:#3a3}
main{display:flex;flex:1;min-height:0}
aside{width:286px;min-width:286px;border-right:1px solid #cfcfcf;background:#f7f7f7;overflow:auto}
aside section{padding:9px 11px;border-bottom:1px solid #e4e4e4}
aside h3{margin:0 0 7px;font-size:12px;font-weight:600;color:#5a5a5a}
label{display:block;margin:0 0 6px;color:#444}
select,input,textarea{width:100%;font:inherit;padding:4px 6px;border:1px solid #bfbfbf;background:#fff;border-radius:2px;color:inherit}
select:focus,input:focus,textarea:focus{outline:1px solid #8a9bb0;border-color:#8a9bb0}
button{font:inherit;padding:4px 10px;border:1px solid #b9b9b9;background:#f2f2f2;border-radius:2px;cursor:pointer;color:#2b2b2b}
button:hover:enabled{background:#e8e8e8}
button:disabled{color:#9a9a9a;cursor:default;background:#efefef}
.row{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.hint{color:#7a7a7a;font-size:12px}
.chk{display:flex;align-items:center;gap:6px;margin-top:8px;color:#444}
.chk input{width:auto}
ul.list{margin:0;padding:0 0 0 16px;color:#444}
ul.list li{margin:2px 0;font-size:12px}
#out{margin:6px 0 0;padding:6px;max-height:140px;overflow:auto;background:#fff;border:1px solid #dcdcdc;border-radius:2px;white-space:pre-wrap;font:12px/1.45 Consolas,"Courier New",monospace;color:#444;display:none}
.chat{display:flex;flex-direction:column;flex:1;min-width:0}
#log{flex:1;overflow:auto;padding:12px 14px;background:#fff}
.msg{margin:0 0 14px}
.msg .who{font-size:11px;color:#8a8a8a;margin-bottom:3px}
.msg .body{white-space:pre-wrap;word-break:break-word}
.msg.user .body{background:#f2f4f6;border:1px solid #e0e3e6;border-radius:3px;padding:7px 9px}
.msg.assistant .body{background:#fff;border:1px solid #ececec;border-radius:3px;padding:7px 9px}
.msg.err .body{background:#fdf3f3;border:1px solid #edcccc;border-radius:3px;padding:7px 9px;color:#8a2f2f}
.meta-line{color:#9a9a9a;font-size:11px;margin:-6px 0 12px}
.compose{border-top:1px solid #cfcfcf;background:#f7f7f7;padding:9px}
.compose textarea{height:74px;resize:vertical}
.send{display:flex;justify-content:flex-end;gap:8px;margin-top:7px}
</style>
</head>
<body>
<div id="app">
  <header>
    <div class="brand">绘里酱 管理面板</div>
    <div class="meta">
      <span id="src"></span>
      <span id="ver"></span>
      <span id="dot" class="dot"></span>
      <span id="status">未连接</span>
    </div>
  </header>
  <main>
    <aside>
      <section>
        <h3>终端工具（聊天后端）</h3>
        <select id="tool"></select>
        <div class="row" style="margin-top:6px">
          <button id="refresh">刷新检测</button>
          <span id="toolstate" class="hint"></span>
        </div>
      </section>
      <section>
        <h3>工作目录</h3>
        <input id="cwd" spellcheck="false" />
      </section>
      <section>
        <h3>人格设定</h3>
        <label>当前人格</label>
        <select id="persona"></select>
        <label style="margin-top:6px">心情覆盖</label>
        <select id="mood"></select>
        <div class="row" style="margin-top:6px">
          <button id="save">保存设定</button>
          <span id="saveres" class="hint"></span>
        </div>
        <label class="chk"><input type="checkbox" id="inject" checked /> 发送时注入当前人格 / 心情</label>
      </section>
      <section>
        <h3>子智慧体</h3>
        <ul id="agents" class="list"></ul>
      </section>
      <section>
        <h3>其它</h3>
        <div class="row">
          <button id="opencfg">打开配置目录</button>
          <button id="sync">同步人格到已装工具</button>
        </div>
        <pre id="out"></pre>
      </section>
    </aside>
    <div class="chat">
      <div id="log"></div>
      <div class="compose">
        <textarea id="msg" placeholder="输入消息；Enter 发送，Shift+Enter 换行"></textarea>
        <div class="send">
          <button id="stop" disabled>停止</button>
          <button id="send">发送</button>
        </div>
      </div>
    </div>
  </main>
</div>
<script>
(function(){
  var state = null, ctrl = null, busy = false;
  function el(id){ return document.getElementById(id); }
  function api(p, b){
    return fetch(p, { method: b ? 'POST' : 'GET', headers: b ? { 'content-type':'application/json' } : {}, body: b ? JSON.stringify(b) : undefined })
      .then(function(r){ return r.json(); });
  }
  function setStatus(t, ok){
    el('status').textContent = t;
    el('dot').className = 'dot' + (ok ? ' on' : '');
  }
  function curTool(){ var id = el('tool').value; return (state.tools||[]).filter(function(t){ return t.id === id; })[0]; }
  function curPersona(){ var n = el('persona').value; return (state.personalities||[]).filter(function(p){ return p.name === n; })[0]; }

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
  function fillPersonas(){
    var sel = el('persona'); sel.innerHTML = '';
    (state.personalities||[]).forEach(function(p){
      var o = document.createElement('option');
      o.value = p.name; o.textContent = p.name + (p.name === state.active ? '（当前）' : '');
      sel.appendChild(o);
    });
    if (!sel.value) sel.value = state.active || '';
    fillMoods();
  }
  function fillMoods(){
    var p = curPersona(), sel = el('mood'); sel.innerHTML = '';
    var d = document.createElement('option');
    d.value = ''; d.textContent = '（不覆盖，默认：' + ((p && p.moodDefault) || '-') + '）';
    sel.appendChild(d);
    ((p && p.moods) || []).forEach(function(m){
      var o = document.createElement('option');
      o.value = m.name; o.textContent = m.name + (m.hint ? ' — ' + String(m.hint).slice(0, 22) : '');
      sel.appendChild(o);
    });
    sel.value = (p && p.moodOverride) || '';
  }
  function fillAgents(){
    var ul = el('agents'); ul.innerHTML = '';
    (state.agents||[]).forEach(function(a){
      var li = document.createElement('li');
      li.textContent = a.name; li.title = a.description || '';
      ul.appendChild(li);
    });
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
    api('/api/state').then(function(s){
      state = s;
      el('ver').textContent = 'v' + s.version;
      el('src').textContent = '设置：' + s.settingsSource;
      el('cwd').value = s.home || '';
      fillTools(); fillPersonas(); fillAgents();
      setStatus('就绪', true);
    }).catch(function(e){ setStatus('读取失败', false); });
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
    busy = true; el('send').disabled = true; el('stop').disabled = false;
    setStatus('生成中…', true);
    ctrl = new AbortController();
    fetch('/api/chat', {
      method: 'POST', headers: { 'content-type':'application/json' }, signal: ctrl.signal,
      body: JSON.stringify({ tool: t.id, message: msg, cwd: el('cwd').value.trim(), inject: el('inject').checked })
    }).then(function(res){
      if (!res.ok) { return res.json().then(function(j){ throw new Error(j.error || ('HTTP ' + res.status)); }); }
      var reader = res.body.getReader(), dec = new TextDecoder(), buf = '';
      function pump(){
        return reader.read().then(function(r){
          if (r.done) return;
          buf += dec.decode(r.value, { stream: true });
          var lines = buf.split('\\n'); buf = lines.pop();
          for (var i = 0; i < lines.length; i++){
            if (!lines[i]) continue;
            var o; try { o = JSON.parse(lines[i]); } catch (e) { continue; }
            if (o.t === 'meta') addMeta('· ' + o.cmd + '  @ ' + o.cwd);
            else if (o.t === 'out') { ab.textContent += o.d; scrollDown(); }
            else if (o.t === 'err') { ab.parentNode.className = 'msg err'; ab.textContent += o.d; scrollDown(); }
            else if (o.t === 'end' && o.code !== 0) addMeta('· 退出码 ' + o.code);
          }
          return pump();
        });
      }
      return pump();
    }).catch(function(e){
      if (e && e.name === 'AbortError') { addMeta('· 已停止'); }
      else { ab.parentNode.className = 'msg err'; ab.textContent += String(e && e.message || e); }
    }).then(function(){
      busy = false; el('stop').disabled = true; onToolChange(); setStatus('就绪', true);
      if (!ab.textContent) ab.textContent = '（无输出）';
    });
  }

  el('refresh').onclick = function(){ api('/api/tools').then(function(r){ state.tools = r.tools; fillTools(); }); };
  el('tool').onchange = onToolChange;
  el('persona').onchange = fillMoods;
  el('save').onclick = function(){
    var p = curPersona();
    api('/api/settings', { active: el('persona').value, mood: el('mood').value || null }).then(function(r){
      el('saveres').textContent = r.ok ? '已保存到 ' + r.settingsSource : ('失败：' + (r.error || ''));
      if (r.ok) { state.active = el('persona').value; }
    });
  };
  el('opencfg').onclick = function(){ api('/api/open', {}).then(function(){ showOut('已在文件管理器中打开配置目录'); }); };
  el('sync').onclick = function(){
    showOut('正在执行 eri update ...');
    api('/api/sync', {}).then(function(r){ showOut(r.error ? ('失败：' + r.error) : (r.out || ('退出码 ' + r.code))); });
  };
  el('send').onclick = send;
  el('stop').onclick = function(){ if (ctrl) ctrl.abort(); };
  el('msg').addEventListener('keydown', function(e){
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
  });
  boot();
})();
</script>
</body>
</html>
`;

module.exports = PAGE;
