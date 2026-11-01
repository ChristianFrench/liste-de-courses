// Icônes en couleur (famille Noto Emoji de Google, licence Apache 2.0) à la place des icônes Material d'une seule couleur.
// Lit outils/icones_noto.json (icône Material → nom Noto), écrit assets/icones/noto/<nom>.png (96 px, fond transparent)
// et lib/composants/icones_noto.dart.
// Usage : npm pack @iconify-json/noto, extraire, puis : node outils/icones_noto.mjs <dossier>/package/icons.json
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
const require = createRequire(import.meta.url);
const { chromium } = require(path.join(execSync('npm root -g').toString().trim(), 'playwright'));

const noto = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const carte = JSON.parse(fs.readFileSync('outils/icones_noto.json', 'utf8'));
const noms = [...new Set(Object.values(carte))].sort();
fs.mkdirSync('assets/icones/noto', { recursive: true });
const navigateur = await chromium.launch();
const page = await navigateur.newPage({ viewport: { width: 96, height: 96 } });
for (const n of noms) {
  const ic = noto.icons[n];
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 ${ic.width ?? noto.width} ${ic.height ?? noto.height}">${ic.body}</svg>`;
  await page.setContent(`<body style="margin:0;background:transparent">${svg}</body>`);
  await page.screenshot({ path: `assets/icones/noto/${n}.png`, omitBackground: true, clip: { x: 0, y: 0, width: 96, height: 96 } });
}
await navigateur.close();
fs.writeFileSync('lib/composants/icones_noto.dart',
  '// Fichier produit par outils/icones_noto.mjs : ne pas modifier à la main.\n' +
  "import 'package:flutter/material.dart';\n\n" +
  '/// Icône Material → image en couleur (assets/icones/<nom>.png).\n' +
  'final iconesNoto = <IconData, String>{\n' +
  Object.entries(carte).map(([m, n]) => `  Icons.${m}: '${n}',\n`).join('') + '};\n');
console.log(noms.length + ' icônes');
