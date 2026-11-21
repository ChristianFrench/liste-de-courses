// Ouvre la page de diagnostic dans Chromium et recopie sa console en annotations GitHub.
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  const lignes = [];
  p.on('console', m => lignes.push(m.text()));
  p.on('pageerror', e => lignes.push('ERREUR PAGE ' + e.message));
  await p.goto('http://localhost:8790/');
  for (let i = 0; i < 40 && !lignes.includes('FIN'); i++) await p.waitForTimeout(1000);
  await b.close();
  console.log('::notice title=navigateur::' + lignes.join(' | ').replace(/\n/g, ' '));
})();
