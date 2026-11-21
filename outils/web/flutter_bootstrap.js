{{flutter_js}}
{{flutter_build_config}}

// Sans le service worker de Flutter (obsolète, il se désinstalle) : le nôtre, hors_ligne.js,
// garde l'application sur l'appareil pour qu'elle s'ouvre sans réseau.
_flutter.loader.load();

// Mise en réserve (plus de 30 Mo) seulement une fois l'application affichée : au premier lancement, elle
// partageait le réseau avec le chargement de l'application et retardait son ouverture (11/11/2026).
if ('serviceWorker' in navigator) {
  let inscrit = false;
  const inscrire = () => {
    if (inscrit) return;
    inscrit = true;
    navigator.serviceWorker.register('hors_ligne.js').catch((e) => console.warn('hors_ligne.js :', e));
  };
  if (navigator.serviceWorker.controller) {
    inscrire(); // déjà en réserve : vérifier tout de suite s'il y a une nouvelle version
  } else {
    window.addEventListener('flutter-first-frame', () => setTimeout(inscrire, 3000));
    setTimeout(inscrire, 60000);
  }
}
// Mise à jour (18/11/2026) : appelé par l'application quand une nouvelle version est publiée. Le service worker
// va chercher la nouvelle version, la met en réserve, puis la page se recharge sur elle.
window.emplettesRecharger = async () => {
  try {
    const r = navigator.serviceWorker && await navigator.serviceWorker.getRegistration();
    if (r) {
      await r.update();
      const attente = r.installing || r.waiting;
      if (attente) {
        await new Promise((fini) => {
          navigator.serviceWorker.addEventListener('controllerchange', fini, { once: true });
          setTimeout(fini, 60000);
        });
      }
    }
  } catch (e) {
    console.warn('mise à jour :', e);
  }
  location.reload();
};

// Demande au navigateur de ne pas effacer la base (IndexedDB) quand la place manque.
if (navigator.storage && navigator.storage.persist) {
  navigator.storage.persist().catch(() => {});
}

// Pas de proposition automatique d'installation (bandeau « Installer l'application » de Chrome sur Android) :
// à côté de l'APK, elle créait une deuxième icône, vide, prise pour l'application. L'ajout reste possible
// par le menu du navigateur.
window.addEventListener('beforeinstallprompt', (e) => e.preventDefault());
