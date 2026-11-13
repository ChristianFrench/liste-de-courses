"""Écrit build/web/hors_ligne.js : le service worker qui garde la version web sur l'appareil
(ouverture sans réseau, par exemple dans un magasin). Lancé par GitHub Actions après « flutter build web »."""
import hashlib, json, pathlib, sys

WEB = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
# Préfixe des réserves : la démonstration (même site, dossier demo/) a le sien, sinon chacune effacerait l'autre.
PREFIXE = sys.argv[2] if len(sys.argv) > 2 else "liste-de-courses-"

# Fichiers inutiles au rendu CanvasKit utilisé ici (symboles de débogage, autres moteurs)
def utile(nom):
    return not (nom.endswith(".symbols") or nom.startswith("canvaskit/skwasm") or nom.startswith("canvaskit/wimp")
                or nom.startswith("canvaskit/webparagraph/") or nom in ("flutter_service_worker.js", "hors_ligne.js"))

fichiers = sorted(p.relative_to(WEB).as_posix() for p in WEB.rglob("*") if p.is_file())
fichiers = [f for f in fichiers if utile(f)]
empreinte = hashlib.sha256()
for f in fichiers:
    empreinte.update(f.encode() + (WEB / f).read_bytes())
version = empreinte.hexdigest()[:16]

modele = r"""'use strict';
// Écrit par outils/web/hors_ligne.py : à chaque nouvelle version, ce fichier change, le navigateur
// le réinstalle, met la nouvelle version en réserve et supprime l'ancienne.
const RESERVE = '__PREFIXE____VERSION__';
const FICHIERS = __FICHIERS__;

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(RESERVE).then((c) => c.addAll(['./', ...FICHIERS])).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((noms) => Promise.all(noms.filter((n) => n.startsWith('__PREFIXE__') && n !== RESERVE).map((n) => caches.delete(n))))
    .then(() => self.clients.claim()));
});

// Tout vient de la réserve ; à défaut, du réseau (et c'est gardé). Une page ouverte sans réseau
// reçoit la page d'accueil de l'application.
self.addEventListener('fetch', (e) => {
  const r = e.request;
  if (r.method !== 'GET' || new URL(r.url).origin !== self.location.origin) return;
  e.respondWith((async () => {
    const reserve = await caches.open(RESERVE);
    if (r.mode === 'navigate') {
      return (await reserve.match('./')) || fetch(r);
    }
    const garde = await reserve.match(r, { ignoreSearch: true });
    if (garde) return garde;
    const reponse = await fetch(r);
    if (reponse.ok) reserve.put(r, reponse.clone());
    return reponse;
  })());
});
"""
(WEB / "hors_ligne.js").write_text(
    modele.replace("__PREFIXE__", PREFIXE).replace("__VERSION__", version).replace("__FICHIERS__", json.dumps(fichiers, indent=0)), encoding="utf-8")
taille = sum((WEB / f).stat().st_size for f in fichiers)
print(f"hors_ligne.js : {len(fichiers)} fichiers mis en réserve ({taille / 1e6:.1f} Mo), version {version}")
