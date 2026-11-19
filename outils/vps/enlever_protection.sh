#!/bin/bash
# Enlève le mot de passe du dossier des essais (19/11/2026, Aristide) :
#   https://<domaine>/telechargements/essai/  redevient libre.
# La console d'administration (telechargements/console/) reste protégée : elle contient le code d'éditeur.
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/ChristianFrench/liste-de-courses/main/outils/vps/enlever_protection.sh)"
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "À lancer avec sudo."; exit 1; }
CONF=/etc/nginx/sites-available/emplettes
cp "$CONF" "$CONF.avant-ouverture"
python3 - "$CONF" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
cle = 'location ^~ /telechargements/essai/ {'
if cle not in t:
    print('Le dossier des essais n\'était pas protégé : rien à faire.')
    sys.exit(0)
debut = t.index(cle)
k, niveau = t.index('{', debut), 0
while True:
    if t[k] == '{':
        niveau += 1
    elif t[k] == '}':
        niveau -= 1
        if niveau == 0:
            break
    k += 1
t = t[:debut].rstrip(' ') + t[k + 1:].lstrip('\n')
open(p, 'w').write(t)
print('Nginx : mot de passe des essais enlevé ; la console reste protégée.')
PY
if nginx -t 2>/dev/null; then
  systemctl reload nginx
  echo "C'est fait : https://$(grep -m1 -oP 'server_name \K[^ ;]+' "$CONF")/telechargements/essai/ est libre."
else
  nginx -t || true
  cp "$CONF.avant-ouverture" "$CONF"; systemctl reload nginx
  echo "Erreur dans la configuration : rien n'a changé."; exit 1
fi
