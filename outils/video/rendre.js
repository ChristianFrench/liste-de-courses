// Rend outils/video/video.html image par image (25 i/s) et assemble la vidéo avec le son.
// Usage : node outils/video/rendre.js <dossier préparé> <sortie.mp4> [paysage|vertical] [début s] [fin s]
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const http = require('http'), fs = require('fs'), path = require('path');
const [dossier, sortie, format = 'paysage', debutS, finS] = process.argv.slice(2);
const types = { '.html': 'text/html', '.json': 'application/json', '.jpg': 'image/jpeg', '.png': 'image/png', '.ttf': 'font/ttf' };
const serveur = http.createServer((q, r) => {
  const f = path.join(dossier, decodeURIComponent(q.url.split('?')[0]));
  fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); return; } r.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); r.end(d); });
}).listen(8791);
(async () => {
  const vertical = format === 'vertical';
  const [L, H] = vertical ? [720, 1280] : [1280, 720];
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: L, height: H } });
  await p.goto(`http://localhost:8791/video.html?format=${format}`);
  const total = await p.evaluate(() => window.charger());
  const t0 = Number(debutS || 0), t1 = Math.min(total, Number(finS || total));
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', '25', '-i', '-',
    '-ss', String(t0), '-t', String(t1 - t0), '-i', path.join(dossier, 'son.wav'),
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-preset', 'medium', '-c:a', 'aac', '-b:a', '128k', '-shortest', '-movflags', '+faststart', sortie],
    { stdio: ['pipe', 'inherit', 'inherit'] });
  const n = Math.round((t1 - t0) * 25);
  for (let i = 0; i < n; i++) {
    await p.evaluate(t => window.rendre(t), t0 + i / 25);
    const img = await p.screenshot({ type: 'jpeg', quality: 92 });
    if (!ff.stdin.write(img)) await new Promise(r => ff.stdin.once('drain', r));
    if (i % 250 === 0) console.log(`${(i / 25).toFixed(0)} s / ${((t1 - t0)).toFixed(0)} s`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  await b.close(); serveur.close();
  console.log('vidéo :', sortie);
})();
