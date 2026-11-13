// Comportements communs du mini site d'Emplettes (toutes les pages).
(function () {
  const $ = (id) => document.getElementById(id);

  // Menu des téléphones
  const burger = document.querySelector('.burger'), nav = $('navigation');
  if (burger) burger.addEventListener('click', () => burger.setAttribute('aria-expanded', nav.classList.toggle('ouvert')));

  // Numéro de la version publiée (lu dans l'application web)
  fetch('web/version.json', { cache: 'no-store' }).then((r) => (r.ok ? r.json() : null)).then((v) => {
    if (!v || !v.version) return;
    if ($('version')) $('version').textContent = 'Version ' + v.version + '.';
    if ($('basVersion')) $('basVersion').textContent = 'Emplettes · version ' + v.version;
  }).catch(() => {});

  // Accueil : l'animation se joue une fois ; « Rejouer » la relance.
  if ($('rejouer')) $('rejouer').addEventListener('click', () => { $('animation').src = 'animation.webp?' + Date.now(); });

  // Découvrir : les écrans un par un, au rythme de chacun (défilement automatique lent, à cocher).
  // Deux visites : l'essentiel (10 écrans) et en détail (20 écrans, adresse decouvrir.html#detail).
  if (window.VISITE && $('diapos')) {
    let ecrans = [], n = 0, courant = 0, minuterie = null;
    function charger(detail) {
      ecrans = detail && window.VISITE_DETAIL ? window.VISITE_DETAIL : window.VISITE;
      n = ecrans.length;
      $('diapos').innerHTML = '';
      $('points').innerHTML = '';
      ecrans.forEach((e, i) => {
        const im = document.createElement('img');
        im.src = 'ecrans/' + encodeURIComponent(e.f) + '.webp';
        im.alt = e.t;
        $('diapos').appendChild(im);
        const p = document.createElement('button');
        p.setAttribute('aria-label', e.t);
        p.addEventListener('click', () => { montrer(i); auto(); });
        $('points').appendChild(p);
      });
      if ($('visiteCourte')) {
        $('visiteCourte').classList.toggle('plein', !detail);
        $('visiteDetail').classList.toggle('plein', !!detail);
        $('visiteCourte').setAttribute('aria-selected', !detail);
        $('visiteDetail').setAttribute('aria-selected', !!detail);
      }
      montrer(0);
      auto();
    }
    function montrer(i) {
      courant = (i + n) % n;
      const e = ecrans[courant];
      $('diapos').querySelectorAll('img').forEach((im, k) => im.classList.toggle('visible', k === courant));
      $('points').querySelectorAll('button').forEach((b, k) => b.classList.toggle('actif', k === courant));
      $('compteur').textContent = (courant + 1) + ' / ' + n;
      $('titreEcran').textContent = e.t;
      $('texteEcran').textContent = e.x;
      $('pointsEcran').innerHTML = '';
      e.p.forEach((t) => { const li = document.createElement('li'); li.textContent = t; $('pointsEcran').appendChild(li); });
    }
    function auto() {
      clearInterval(minuterie);
      if ($('auto').checked) minuterie = setInterval(() => montrer(courant + 1), 9000);
    }
    $('precedent').addEventListener('click', () => { montrer(courant - 1); auto(); });
    $('suivant').addEventListener('click', () => { montrer(courant + 1); auto(); });
    $('auto').addEventListener('change', auto);
    if ($('visiteCourte')) {
      $('visiteCourte').addEventListener('click', () => { history.replaceState(null, '', '#'); charger(false); });
      $('visiteDetail').addEventListener('click', () => { history.replaceState(null, '', '#detail'); charger(true); });
    }
    document.addEventListener('keydown', (ev) => {
      if (ev.key === 'ArrowRight') { montrer(courant + 1); auto(); }
      if (ev.key === 'ArrowLeft') { montrer(courant - 1); auto(); }
    });
    // Glisser le doigt sur le téléphone
    let x0 = null;
    $('diapos').addEventListener('touchstart', (ev) => { x0 = ev.touches[0].clientX; }, { passive: true });
    $('diapos').addEventListener('touchend', (ev) => {
      if (x0 === null) return;
      const dx = ev.changedTouches[0].clientX - x0;
      if (Math.abs(dx) > 40) { montrer(courant + (dx < 0 ? 1 : -1)); auto(); }
      x0 = null;
    });
    charger(location.hash === '#detail');
  }

  // Essayer : dans la page (cadre de téléphone) ou dans une fenêtre détachée
  if ($('dansLaPage')) {
    $('dansLaPage').addEventListener('click', () => {
      if (!$('cadre').querySelector('iframe')) $('cadre').innerHTML = '<iframe src="demo/" title="Démonstration d\'Emplettes"></iframe>';
      $('zoneCadre').classList.add('visible');
      $('zoneCadre').scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
    $('fenetre').addEventListener('click', () => {
      const h = Math.min(860, screen.availHeight - 40), l = Math.round(h * 390 / 844);
      const w = window.open('demo/', 'emplettes-demo', `popup=yes,width=${l},height=${h},left=${screen.availWidth - l - 30},top=20`);
      if (!w) location.href = 'demo/'; // fenêtres bloquées : on l'ouvre dans l'onglet
    });
  }
})();
