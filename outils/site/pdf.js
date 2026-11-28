// PDF des documents du site (Chromium de Playwright) : node outils/site/pdf.js
// Sert docs/ en local, imprime le mode d'emploi (A4) et le dépliant (A4 paysage), et fait l'aperçu du dépliant.
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const racine = path.resolve(__dirname, '../../docs');
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.ttf': 'font/ttf' };
const serveur = http.createServer((q, r) => {
  const f = path.join(racine, decodeURIComponent(q.url.split('?')[0]));
  fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); } else { r.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); r.end(d); } });
}).listen(8766);
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ locale: 'fr-FR' });
  await p.goto('http://localhost:8766/documents/mode-emploi.html', { waitUntil: 'networkidle' });
  await p.pdf({ path: path.join(racine, "documents/Emplettes - Mode d'emploi.pdf"), format: 'A4', printBackground: true, preferCSSPageSize: true,
    displayHeaderFooter: true, headerTemplate: '<span></span>',
    footerTemplate: '<div style="width:100%;font:9px sans-serif;color:#557B66;text-align:center">Emplettes · Mode d\'emploi · <span class="pageNumber"></span> / <span class="totalPages"></span></div>' });
  await p.goto('http://localhost:8766/documents/depliant.html', { waitUntil: 'networkidle' });
  await p.pdf({ path: path.join(racine, 'documents/Emplettes - Depliant.pdf'), printBackground: true, preferCSSPageSize: true });
  // Aperçu : la couverture et le dos du dépliant
  const a = await b.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: 1 });
  await a.goto('http://localhost:8766/documents/depliant.html', { waitUntil: 'networkidle' });
  await a.emulateMedia({ media: 'print' });
  await a.locator('.page').first().screenshot({ path: path.join(racine, 'documents/depliant-apercu.png') });
  await b.close();
  serveur.close();
})();
