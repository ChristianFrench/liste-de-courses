// Icônes Twemoji (X, ex-Twitter, licence CC BY 4.0) : assets/icones/twemoji/<nom Noto>.png (96 px, fond transparent).
// Usage : npm pack @iconify-json/twemoji @iconify-json/noto, extraire, puis :
//   node outils/icones_twemoji.mjs <twemoji>/package <noto>/package
import fs from 'node:fs'; import path from 'node:path'; import { createRequire } from 'node:module'; import { execSync } from 'node:child_process';
const require = createRequire(import.meta.url);
const { chromium } = require(path.join(execSync('npm root -g').toString().trim(), 'playwright'));
const [tw, no] = process.argv.slice(2);
const noto = JSON.parse(fs.readFileSync(path.join(no, 'chars.json')));
const inv = {}; for (const [c, n] of Object.entries(noto)) (inv[n] ??= []).push(c);
const noms = [...new Set(Object.values(JSON.parse(fs.readFileSync('outils/icones_noto.json'))))].sort();
const ic = JSON.parse(fs.readFileSync(path.join(tw, 'icons.json'))); const ch = JSON.parse(fs.readFileSync(path.join(tw, 'chars.json')));
fs.mkdirSync('assets/icones/twemoji', { recursive: true });
const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 96, height: 96 } });
for (const n of noms) {
  let nom = ic.icons[n] ? n : null;
  for (const c of inv[n] || []) for (const k of [c, c.replace(/-fe0f/g, ''), c + '-fe0f']) if (ch[k]) nom = ch[k];
  const i = ic.icons[nom] || ic.icons[ic.aliases?.[nom]?.parent];
  await p.setContent(`<body style="margin:0"><svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 ${i.width ?? ic.width} ${i.height ?? ic.height}">${i.body}</svg></body>`);
  await p.screenshot({ path: `assets/icones/twemoji/${n}.png`, omitBackground: true, clip: { x: 0, y: 0, width: 96, height: 96 } });
}
await b.close();
console.log(noms.length + ' icônes');
