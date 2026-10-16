'use strict';
// 生成 ui/icon.ico：默认从 ui/logo.png（绘里酱 logo，256px 8-bit RGBA）缩放打包；
// ui/logo.png 缺失或解析失败时回退到程序化樱花粉心形（与面板主题同款）。
// 纯 Node 实现（zlib 解/编 PNG + 手写 ICO 容器），心形用 4x 超采样抗锯齿。
// 用法: node ui/make-icon.js
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const C1 = [0xff, 0xb7, 0xc5];
const C2 = [0xff, 0x9c, 0xba];
const SIZES = [256, 64, 48, 32, 16];
const SS = 4;

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}

function png(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

const lerp = (a, b, t) => a + (b - a) * t;

function inTile(u, v) {
  const r = 0.225;
  const cx = Math.min(Math.max(u, r), 1 - r);
  const cy = Math.min(Math.max(v, r), 1 - r);
  const dx = u - cx, dy = v - cy;
  return dx * dx + dy * dy <= r * r;
}

const HEART_S = 0.585 / 2.278;
// 心形隐式方程 bbox 的曲线坐标中心 (ymin+ymax)/2 = -0.19
const HEART_YC = -0.19;

function inHeart(u, v) {
  const hx = (u - 0.5) / HEART_S;
  const hy = HEART_YC + (0.53 - v) / HEART_S;
  const a = hx * hx + hy * hy - 1;
  return a * a * a - hx * hx * hy * hy * hy <= 0;
}

function inStar(px, py, cx, cy, r) {
  const dx = Math.abs(px - cx) / r, dy = Math.abs(py - cy) / r;
  return Math.pow(dx, 2 / 3) + Math.pow(dy, 2 / 3) <= 1;
}

function render(S) {
  const out = Buffer.alloc(S * S * 4);
  const n2 = SS * SS;
  for (let y = 0; y < S; y++) {
    for (let x = 0; x < S; x++) {
      let ar = 0, ag = 0, ab = 0, cov = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const u = (x + (sx + 0.5) / SS) / S;
          const v = (y + (sy + 0.5) / SS) / S;
          if (!inTile(u, v)) continue;
          cov++;
          let r, g, b;
          if (inHeart(u, v) || inStar(u, v, 0.775, 0.235, 0.088) || inStar(u, v, 0.660, 0.128, 0.040)) {
            r = 255; g = 255; b = 255;
          } else {
            const t = (u + v) / 2;
            r = lerp(C1[0], C2[0], t);
            g = lerp(C1[1], C2[1], t);
            b = lerp(C1[2], C2[2], t);
          }
          ar += r; ag += g; ab += b;
        }
      }
      const i = (y * S + x) * 4;
      if (cov > 0) {
        out[i] = Math.round(ar / cov);
        out[i + 1] = Math.round(ag / cov);
        out[i + 2] = Math.round(ab / cov);
        out[i + 3] = Math.round((cov / n2) * 255);
      }
    }
  }
  return out;
}

function decodePng(buf) {
  if (buf.length < 8 || buf.readUInt32BE(0) !== 0x89504E47) throw new Error('不是 PNG 文件');
  let pos = 8, ihdr = null;
  const idat = [];
  while (pos + 8 <= buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString('ascii', pos + 4, pos + 8);
    if (type === 'IHDR') ihdr = buf.subarray(pos + 8, pos + 8 + len);
    else if (type === 'IDAT') idat.push(buf.subarray(pos + 8, pos + 8 + len));
    else if (type === 'IEND') break;
    pos += 12 + len;
  }
  if (!ihdr) throw new Error('缺少 IHDR');
  const w = ihdr.readUInt32BE(0), h = ihdr.readUInt32BE(4);
  if (ihdr[8] !== 8 || ihdr[9] !== 6 || ihdr[12] !== 0) throw new Error('仅支持 8-bit RGBA 非隔行 PNG');
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = 1 + w * 4;
  if (raw.length !== stride * h) throw new Error('IDAT 长度不符');
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    if (raw[y * stride] !== 0) throw new Error('不支持 PNG 滤波类型 ' + raw[y * stride]);
    raw.copy(out, y * w * 4, y * stride + 1, (y + 1) * stride);
  }
  return { w, h, rgba: out };
}

function resize(src, sw, sh, dw, dh) {
  const out = Buffer.alloc(dw * dh * 4);
  for (let y = 0; y < dh; y++) {
    const y0 = Math.floor(y * sh / dh), y1 = Math.max(y0 + 1, Math.floor((y + 1) * sh / dh));
    for (let x = 0; x < dw; x++) {
      const x0 = Math.floor(x * sw / dw), x1 = Math.max(x0 + 1, Math.floor((x + 1) * sw / dw));
      let r = 0, g = 0, b = 0, a = 0, n = 0;
      for (let yy = y0; yy < y1; yy++) {
        for (let xx = x0; xx < x1; xx++) {
          const i = (yy * sw + xx) * 4, al = src[i + 3];
          r += src[i] * al; g += src[i + 1] * al; b += src[i + 2] * al;
          a += al; n++;
        }
      }
      const o = (y * dw + x) * 4;
      if (a > 0) {
        out[o] = Math.round(r / a);
        out[o + 1] = Math.round(g / a);
        out[o + 2] = Math.round(b / a);
      }
      out[o + 3] = Math.round(a / n);
    }
  }
  return out;
}

function buildIco(images) {
  const n = images.length;
  const dir = Buffer.alloc(6);
  dir.writeUInt16LE(0, 0);
  dir.writeUInt16LE(1, 2);
  dir.writeUInt16LE(n, 4);
  const entries = [];
  let offset = 6 + 16 * n;
  for (const img of images) {
    const e = Buffer.alloc(16);
    e[0] = img.size >= 256 ? 0 : img.size;
    e[1] = img.size >= 256 ? 0 : img.size;
    e[2] = 0; e[3] = 0;
    e.writeUInt16LE(1, 4);
    e.writeUInt16LE(32, 6);
    e.writeUInt32LE(img.png.length, 8);
    e.writeUInt32LE(offset, 12);
    entries.push(e);
    offset += img.png.length;
  }
  return Buffer.concat([dir, ...entries, ...images.map((i) => i.png)]);
}

function buildIcon() {
  const logoPath = path.join(__dirname, 'logo.png');
  let images = null, source = '';
  if (fs.existsSync(logoPath)) {
    try {
      const { w, h, rgba } = decodePng(fs.readFileSync(logoPath));
      images = SIZES.map((size) => ({ size, png: png(size, size, resize(rgba, w, h, size, size)) }));
      source = 'logo.png (' + w + 'x' + h + ')';
    } catch (err) {
      console.error('==> logo.png 解析失败（' + err.message + '），回退内置心形');
    }
  }
  if (!images) {
    images = SIZES.map((size) => ({ size, png: png(size, size, render(size)) }));
    source = '内置樱花心形';
  }
  return { ico: buildIco(images), source };
}

function main() {
  const { ico, source } = buildIcon();
  const out = path.join(__dirname, 'icon.ico');
  fs.writeFileSync(out, ico);
  console.log('==> 已生成 ' + out + ' (' + ico.length + ' bytes, ' + SIZES.join('/') + ', 源: ' + source + ')');
}

if (require.main === module) main();

module.exports = { render, png, buildIco, decodePng, resize, buildIcon };
