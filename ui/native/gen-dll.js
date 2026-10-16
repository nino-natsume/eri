'use strict';
// 将 libwebview.dll 打包为 base64 模块 dll.js（供编译进 exe 后运行时解压使用）。
// 用法: node ui/native/gen-dll.js
const fs = require('fs');
const path = require('path');

const dllPath = path.join(__dirname, 'libwebview.dll');
const outPath = path.join(__dirname, 'dll.js');
const buf = fs.readFileSync(dllPath);

const content = [
  "'use strict';",
  '// 自动生成: node ui/native/gen-dll.js (勿手改)',
  '// 源: libwebview.dll (webview-bun 2.4.0 / webview, MIT)',
  'module.exports = "' + buf.toString('base64') + '";',
  '',
].join('\n');

fs.writeFileSync(outPath, content);
console.log('==> 已生成 ' + outPath + ' (' + buf.length + ' bytes DLL -> ' + content.length + ' bytes base64)');
