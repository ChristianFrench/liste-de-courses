{{flutter_js}}
{{flutter_build_config}}

// Sans le service worker de Flutter (obsolète, il se désinstalle) : le nôtre, hors_ligne.js,
// garde l'application sur l'appareil pour qu'elle s'ouvre sans réseau.
_flutter.loader.load();

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('hors_ligne.js').catch((e) => console.warn('hors_ligne.js :', e));
}
// Demande au navigateur de ne pas effacer la base (IndexedDB) quand la place manque.
if (navigator.storage && navigator.storage.persist) {
  navigator.storage.persist().catch(() => {});
}

// Pas de proposition automatique d'installation (bandeau « Installer l'application » de Chrome sur Android) :
// à côté de l'APK, elle créait une deuxième icône, vide, prise pour l'application. L'ajout reste possible
// par le menu du navigateur.
window.addEventListener('beforeinstallprompt', (e) => e.preventDefault());
