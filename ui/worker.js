'use strict';
// 面板后端 Worker：拥有独立事件循环（可自由 spawn 子进程、跑异步任务），
// 结果与流式事件写入 SharedArrayBuffer 环形队列，由主线程在 bind 回调里取走。

const { parentPort, workerData } = require('worker_threads');
const core = require('./core.js');
const { createRing } = require('./ring.js');

const ring = createRing(workerData.sab);
const stoppers = new Map();

parentPort.on('message', (m) => {
  if (!m) return;
  if (m.stop) {
    const fn = stoppers.get(m.sid);
    if (fn) { try { fn(); } catch { /* ignore */ } }
    return;
  }
  run(m);
});

async function run(job) {
  const emit = (ev) => ring.write({ sid: job.sid, t: 'ev', ev });
  try {
    const r = await core.handle(
      { path: job.path, method: job.method, body: job.body },
      { emit, setStopper: (fn) => stoppers.set(job.sid, fn) },
    );
    ring.write({ sid: job.sid, t: 'result', status: (r && r.status) || 200, body: (r && r.body) || {} });
  } catch (err) {
    ring.write({ sid: job.sid, t: 'error', error: String((err && err.message) || err) });
  } finally {
    stoppers.delete(job.sid);
  }
}
