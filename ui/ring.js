'use strict';
// 无端口面板：Worker → 主线程 的单向消息环形队列（基于 SharedArrayBuffer）。
// 主线程被 webview_run() 阻塞期间无法跑事件循环，因此 Worker 的所有产出
// （流式事件/任务结果）都写入这里有界队列，由主线程在 bind 回调里 drain 取走。
// 布局: [0..8) = Int32[tail, head]（单调 u32 计数），其后 CAP 字节数据区。

const CAP = 1 << 20;
const HEADER = 8;
const RING_SIZE = HEADER + CAP;

const u32 = (n) => n >>> 0;

function createRing(sab) {
  const header = new Int32Array(sab, 0, 2);
  const data = new Uint8Array(sab, HEADER, CAP);
  const enc = new TextEncoder();
  const dec = new TextDecoder();

  function putBytes(pos, buf) {
    const start = pos % CAP;
    const first = Math.min(buf.length, CAP - start);
    data.set(buf.subarray(0, first), start);
    if (first < buf.length) data.set(buf.subarray(first), 0);
  }

  function getBytes(pos, len) {
    const start = pos % CAP;
    const first = Math.min(len, CAP - start);
    if (first === len) return data.slice(start, start + len);
    const out = new Uint8Array(len);
    out.set(data.subarray(start, start + first), 0);
    out.set(data.subarray(0, len - first), first);
    return out;
  }

  function putLen(pos, n) {
    const b = new Uint8Array(4);
    b[0] = n & 255;
    b[1] = (n >>> 8) & 255;
    b[2] = (n >>> 16) & 255;
    b[3] = (n >>> 24) & 255;
    putBytes(pos, b);
  }

  function getLen(pos) {
    const b = getBytes(pos, 4);
    return (b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24)) >>> 0;
  }

  // 队列满时的暂存（编码后的帧），下次写入前重试
  const overflow = [];

  function writeDirect(pos, bytes) {
    putLen(pos, bytes.length);
    putBytes(pos + 4, bytes);
  }

  function flushOverflow(tail, head) {
    while (overflow.length) {
      const bytes = overflow[0];
      const need = 4 + bytes.length;
      if (u32(tail - head) + need > CAP) break;
      writeDirect(u32(tail), bytes);
      tail = u32(tail + need);
      overflow.shift();
    }
    return tail;
  }

  return {
    write(obj) {
      let bytes;
      try { bytes = enc.encode(JSON.stringify(obj)); } catch { return; }
      let tail = Atomics.load(header, 0) >>> 0;
      const head = Atomics.load(header, 1) >>> 0;
      tail = flushOverflow(tail, head);
      const need = 4 + bytes.length;
      if (u32(tail - head) + need > CAP) { overflow.push(bytes); return; }
      writeDirect(tail, bytes);
      Atomics.store(header, 0, (tail + need) | 0);
    },

    drain() {
      const out = [];
      let head = Atomics.load(header, 1) >>> 0;
      const tail = Atomics.load(header, 0) >>> 0;
      while (u32(tail - head) >= 4) {
        const len = getLen(head);
        if (len > CAP) { head = tail; break; }
        if (u32(tail - head) < 4 + len) break;
        const bytes = getBytes(head + 4, len);
        head = u32(head + 4 + len);
        try { out.push(JSON.parse(dec.decode(bytes))); } catch { /* skip bad frame */ }
      }
      if (head !== (Atomics.load(header, 1) >>> 0)) Atomics.store(header, 1, head | 0);
      return out;
    },
  };
}

module.exports = { createRing, RING_SIZE };
