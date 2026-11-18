#!/bin/bash
# Protège par mot de passe les versions d'essai et la console d'administration (18/11/2026, Aristide) :
#   https://<domaine>/telechargements/essai/    (vos essais ; l'application démo y lit aussi ses mises à jour)
#   https://<domaine>/telechargements/console/  (console d'administration : vous seul)
# Le dépôt officiel https://<domaine>/telechargements/ reste libre (site, invitations, mises à jour).
#
# À lancer une fois sur le serveur, connecté en ssh :
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/ChristianFrench/liste-de-courses/main/outils/vps/proteger_telechargements.sh)"
# Il demande votre nom et votre mot de passe (ils ne quittent pas le serveur), puis affiche une valeur
# à saisir comme secret GitHub TELECHARGEMENTS_ESSAI (le compte de l'application pour le dossier essai).
# À relancer après une réinstallation du serveur (installer.sh réécrit la configuration de Nginx).
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "À lancer avec sudo."; exit 1; }
CONF=/etc/nginx/sites-available/emplettes
[ -f "$CONF" ] || { echo "Configuration Nginx introuvable : $CONF"; exit 1; }

read -rp "Votre nom d'utilisateur [aristide] : " NOM
NOM=${NOM:-aristide}
while true; do
  read -rsp "Votre mot de passe : " MDP; echo
  read -rsp "Encore une fois : " MDP2; echo
  [ -n "$MDP" ] && [ "$MDP" = "$MDP2" ] && break
  echo "Vide ou différent, recommencez."
done
APPLI=$(openssl rand -hex 16)
printf '%s:%s\n' "$NOM" "$(openssl passwd -apr1 "$MDP")" > /etc/nginx/emplettes-console.htpasswd
{ printf '%s:%s\n' "$NOM" "$(openssl passwd -apr1 "$MDP")"; printf 'application:%s\n' "$(openssl passwd -apr1 "$APPLI")"; } > /etc/nginx/emplettes-essai.htpasswd
chown root:www-data /etc/nginx/emplettes-*.htpasswd
chmod 640 /etc/nginx/emplettes-*.htpasswd

cp "$CONF" "$CONF.avant-protection"
python3 - "$CONF" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p).read()
if 'emplettes-essai.htpasswd' not in t:
    lignes = t.split('\n')
    i = next(k for k, l in enumerate(lignes) if 'location /telechargements/ {' in l)
    l = lignes[i]
    essai = l.replace('location /telechargements/ {', 'location /telechargements/essai/ { auth_basic "Emplettes - essais"; auth_basic_user_file /etc/nginx/emplettes-essai.htpasswd;')
    console = l.replace('location /telechargements/ {', 'location /telechargements/console/ { auth_basic "Emplettes - console"; auth_basic_user_file /etc/nginx/emplettes-console.htpasswd;')
    lignes[i + 1:i + 1] = [essai, console]
    open(p, 'w').write('\n'.join(lignes))
    print('Nginx : dossiers essai/ et console/ protégés.')
else:
    print('Nginx : protection déjà en place, mots de passe renouvelés.')
PY
if nginx -t 2>/dev/null; then
  systemctl reload nginx
else
  nginx -t || true
  cp "$CONF.avant-protection" "$CONF"; systemctl reload nginx
  echo "Erreur dans la configuration : rien n'a changé."; exit 1
fi
echo
echo "C'est fait. Saisissez maintenant ce secret dans GitHub (Settings > Secrets and variables > Actions) :"
echo
echo "  Nom    : TELECHARGEMENTS_ESSAI"
echo "  Valeur : application:$APPLI"
echo
