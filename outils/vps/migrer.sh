#!/usr/bin/env bash
# Déménagement du serveur d'Emplettes vers un autre VPS (19/11/2026, serveur du Canada trop lent).
# Rien ne change pour les applications ni pour GitHub : mêmes noms (emplettes.eu, mqtt., ntfy.), mêmes mots de passe,
# même clé de publication. Seule l'adresse IP des DNS change.
#
# 1. Sur l'ANCIEN serveur :
#      curl -fsSL https://raw.githubusercontent.com/ChristianFrench/liste-de-courses/main/outils/vps/migrer.sh -o migrer.sh
#      sudo bash migrer.sh exporter
#    → crée ~/emplettes-demenagement.tar.gz (mots de passe, état des foyers, catalogue publié, certificats, site,
#      téléchargements). Ce fichier contient des secrets : ne l'envoyez à personne, effacez-le après le déménagement.
# 2. Depuis votre PC, recopiez-le sur le NOUVEAU serveur (Debian 12) :
#      scp debian@ANCIENNE_IP:emplettes-demenagement.tar.gz .
#      scp emplettes-demenagement.tar.gz debian@NOUVELLE_IP:
# 3. Chez OVH, zone DNS d'emplettes.eu : remplacez l'ancienne IP par la nouvelle (emplettes.eu, www, mqtt, ntfy).
# 4. Sur le NOUVEAU serveur, une heure après :
#      curl -fsSL https://raw.githubusercontent.com/ChristianFrench/liste-de-courses/main/outils/vps/migrer.sh -o migrer.sh
#      sudo bash migrer.sh importer
#    Répondez Entrée aux questions (les réponses de l'ancien serveur sont reprises). Se relance sans risque.
set -euo pipefail
vert() { printf '\n\033[1;32m== %s\033[0m\n' "$*"; }
stop() { printf '\n\033[1;31mArrêt : %s\033[0m\n' "$*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || stop "lancez le script avec sudo : sudo bash migrer.sh exporter|importer"
SOURCE="https://raw.githubusercontent.com/ChristianFrench/liste-de-courses/main/outils/vps"
ADMIN="${SUDO_USER:-debian}"
ARCHIVE="$(getent passwd "$ADMIN" | cut -d: -f6)/emplettes-demenagement.tar.gz"
REGLAGES=(/etc/emplettes /etc/mosquitto/motsdepasse /etc/letsencrypt /etc/nginx/emplettes-essai.htpasswd /etc/nginx/emplettes-console.htpasswd)
DONNEES=(/var/lib/mosquitto /var/lib/ntfy /var/cache/ntfy /srv/emplettes/site)

case "${1:-}" in
exporter)
  vert "Arrêt très bref du partage et des notifications, le temps d'une copie cohérente"
  systemctl stop mosquitto ntfy
  trap 'systemctl start mosquitto ntfy' EXIT
  tar -czf "$ARCHIVE" --ignore-failed-read "${REGLAGES[@]}" "${DONNEES[@]}" 2>/dev/null || true
  chown "$ADMIN": "$ARCHIVE"; chmod 600 "$ARCHIVE"
  vert "Terminé : $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
  echo "   Contenu :"; tar -tzf "$ARCHIVE" | cut -d/ -f1-4 | sort -u | sed 's/^/     /' | head -20
  ;;
importer)
  [ -s "$ARCHIVE" ] || stop "$ARCHIVE introuvable : recopiez-le d'abord depuis l'ancien serveur (étape 2)."
  grep -q '^VERSION_ID="12"' /etc/os-release || stop "ce script est prévu pour Debian 12."
  vert "1/4 Réglages et mots de passe de l'ancien serveur"
  tar -xzf "$ARCHIVE" -C / etc
  vert "2/4 Installation (mêmes réponses, mêmes mots de passe : répondez Entrée, et « n » pour ne pas les changer)"
  curl -fsSL "$SOURCE/installer.sh" -o /tmp/installer.sh
  bash /tmp/installer.sh
  vert "3/4 État des foyers, catalogue publié, notifications, site et téléchargements"
  systemctl stop mosquitto ntfy
  rm -rf /var/lib/mosquitto /var/lib/ntfy /var/cache/ntfy
  tar -xzf "$ARCHIVE" -C / var srv
  chown -R mosquitto:mosquitto /var/lib/mosquitto
  chown -R ntfy:ntfy /var/lib/ntfy /var/cache/ntfy
  chown -R deploiement:deploiement /srv/emplettes/site 2>/dev/null || true
  systemctl start mosquitto ntfy
  vert "4/4 Protection des essais et de la console (vos mots de passe sont gardés)"
  curl -fsSL "$SOURCE/proteger_telechargements.sh" -o /tmp/proteger.sh
  echo O | bash /tmp/proteger.sh | grep -v 'TELECHARGEMENTS_ESSAI' || true
  for s in nginx mosquitto ntfy relais-mail; do systemctl is-active --quiet "$s" && echo "   bon    $s" || echo "   ÉCHEC  $s"; done
  vert "Terminé. Rien à changer dans GitHub. Effacez l'archive ici et sur votre PC : rm $ARCHIVE"
  ;;
*) stop "précisez exporter (ancien serveur) ou importer (nouveau serveur)." ;;
esac
