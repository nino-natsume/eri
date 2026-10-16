#!/usr/bin/env node
'use strict';
// 版本同步: 以 package.json 为单一真源, 更新 package-lock.json 的
// version 与 PKGBUILD / .SRCINFO 的 pkgver、sha256sums。
// 由 npm 的 "version" 生命周期脚本自动调用
// (npm version <bump> / npm publish 前), 也可手动 `node sync-version.js`。
const fs = require('fs');
const path = require('path');
const { createHash } = require('crypto');

const root = __dirname;
const version = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8')).version;
const hash = (f) => createHash('sha256').update(fs.readFileSync(path.join(root, f))).digest('hex');

// ---- package-lock.json: version (顶层 + packages[""]) ----
const lockPath = path.join(root, 'package-lock.json');
let lockChanged = false;
if (fs.existsSync(lockPath)) {
  const lock = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
  if (lock.version !== version) { lock.version = version; lockChanged = true; }
  if (lock.packages && lock.packages[''] && lock.packages[''].version !== version) {
    lock.packages[''].version = version;
    lockChanged = true;
  }
  if (lockChanged) fs.writeFileSync(lockPath, `${JSON.stringify(lock, null, 2)}\n`);
}

// ---- PKGBUILD: pkgver + sha256sums ----
const pkPath = path.join(root, 'PKGBUILD');
let pk = fs.readFileSync(pkPath, 'utf8');
pk = pk.replace(/^pkgver=.*$/m, `pkgver=${version}`);
const srcBlock = pk.match(/source=\(([\s\S]*?)\)/);
if (!srcBlock) throw new Error('PKGBUILD: 未找到 source=()');
const sources = srcBlock[1].split('\n').map((s) => s.trim()).filter(Boolean);
const sums = sources.map((f) => `  '${hash(f)}'`).join('\n');
pk = pk.replace(/sha256sums=\([\s\S]*?\)/, `sha256sums=(\n${sums}\n)`);
fs.writeFileSync(pkPath, pk);

// ---- .SRCINFO: pkgver + sha256sums ----
const siPath = path.join(root, '.SRCINFO');
let si = fs.readFileSync(siPath, 'utf8');
si = si.replace(/^\tpkgver = .*$/m, `\tpkgver = ${version}`);
let i = 0;
si = si.replace(/^\tsha256sums = .*$/gm, () => `\tsha256sums = ${hash(sources[i++])}`);
fs.writeFileSync(siPath, si);

console.log(`==> 版本已同步为 ${version}: package-lock.json (version) + PKGBUILD / .SRCINFO (pkgver + sha256sums)`);
