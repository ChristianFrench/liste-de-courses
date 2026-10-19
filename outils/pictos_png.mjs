// Convertit les pictogrammes SVG (assets/pictos/*.svg) en PNG 96 px posés sur le rond pâle
// de leur rayon, et écrit la liste des pictogrammes dans lib/donnees/pictos.dart.
// Usage : node outils/pictos_png.mjs   (Playwright et Chromium requis)
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
const require = createRequire(import.meta.url);
const { chromium } = require(path.join(execSync('npm root -g').toString().trim(), 'playwright'));

const dossier = 'assets/pictos';
const sortie = path.join(dossier, 'png');
fs.mkdirSync(sortie, { recursive: true });
const catalogue = JSON.parse(fs.readFileSync('assets/catalogue_type.json', 'utf8'));
const slug = s => s.replace(/œ/g, 'oe').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const pales = ['#E2F3D8','#FDE1DF','#FFE9D6','#DCEFFC','#E3F0FD','#FFF4CC','#FCE4EC','#E8F5E9','#FFF0D9','#FBE9E7','#FFF3E0','#EEF5DB','#FFEBD6','#F3E5F5','#FFF8E1','#FCE4EC','#E0F4FB','#F8E3EF','#E0F7FA','#F3E5F5','#FDEDF3','#F1E8FB','#E8EAF6','#E0F2F1','#E1F5FE','#FFF3E0','#E8F5E9','#FFFDE7','#FBE9E7','#E8EAF6','#EFEBE9'];
const couleur = {};
catalogue.rayons.forEach((r, i) => { couleur[slug(r.nom)] = pales[i % pales.length]; });

const noms = fs.readdirSync(dossier).filter(f => f.endsWith('.svg')).map(f => f.slice(0, -4)).sort();
const navigateur = await chromium.launch();
const page = await navigateur.newPage({ viewport: { width: 96, height: 96 }, deviceScaleFactor: 1 });
for (const n of noms) {
  const fond = couleur[n.split('--')[0]] ?? '#FFF3E0';
  const svg = fs.readFileSync(path.join(dossier, n + '.svg'), 'utf8').replace('<svg ', '<svg width="78" height="78" ');
  await page.setContent(`<body style="margin:0;background:transparent"><div style="width:96px;height:96px;border-radius:50%;background:${fond};display:grid;place-items:center">${svg}</div></body>`);
  await page.screenshot({ path: path.join(sortie, n + '.png'), omitBackground: true });
}
await navigateur.close();

fs.writeFileSync('lib/donnees/pictos.dart',
  '// Fichier produit par outils/pictos_png.mjs : ne pas modifier à la main.\n' +
  '// Pictogrammes disponibles (assets/pictos/png/<nom>.png) : « rayon » ou « rayon--secteur ».\n\n' +
  'const pictosDisponibles = <String>{\n' + noms.map(n => `  '${n}',\n`).join('') + '};\n');
console.log(noms.length + ' pictogrammes');
