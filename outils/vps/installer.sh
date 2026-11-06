#!/usr/bin/env bash
# Installation et mise à jour du serveur d'Emplettes sur un VPS Debian 12 (04/11/2026).
#
#   curl -fsSL https://raw.githubusercontent.com/ChristianFrench/liste-de-courses/main/outils/vps/installer.sh -o installer.sh
#   sudo bash installer.sh
#
# Installe : sécurité de base (pare-feu, fail2ban, mises à jour automatiques), Nginx + Let's Encrypt (site, web,
# démonstration, téléchargements), Mosquitto (partage, 8883 TLS + WebSocket derrière Nginx), ntfy (notifications),
# relais de mails (boîte Zimbra du domaine), compte de publication pour GitHub, sauvegardes de nuit.
# Se relance sans risque : les réponses sont gardées dans /etc/emplettes/installation.conf (lisible par root seul),
# les mots de passe déjà en place sont conservés sauf si vous demandez à les changer.
# Aucun mot de passe ne quitte ce serveur ; ne les envoyez à personne.
set -euo pipefail

SOURCE="https://raw.githubusercontent.com/ChristianFrench/liste-de-courses/main/outils/vps"
CONF=/etc/emplettes/installation.conf
SRV=/srv/emplettes

vert() { printf '\n\033[1;32m== %s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
stop() { printf '\n\033[1;31mArrêt : %s\033[0m\n' "$*" >&2; exit 1; }
demander() { # demander VAR "Question" "défaut"
  local v="${!1:-$3}" r
  read -r -p "   $2 [${v}] : " r || true
  printf -v "$1" '%s' "${r:-$v}"
}
secret() { # secret VAR "Question" : saisi deux fois, non affiché
  local a b
  while true; do
    read -r -s -p "   $2 : " a; echo
    read -r -s -p "   Encore une fois : " b; echo
    [ -n "$a" ] && [ "$a" = "$b" ] && break
    echo "   Les deux saisies diffèrent ou sont vides, recommencez."
  done
  printf -v "$1" '%s' "$a"
}
# Avec « set -o pipefail », tr reçoit SIGPIPE quand head s'arrête : le « || true » évite l'arrêt silencieux du script.
aleatoire() { (LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-32}") || true; }

[ "$(id -u)" = 0 ] || stop "lancez le script avec sudo : sudo bash installer.sh"
grep -q '^VERSION_ID="12"' /etc/os-release || stop "ce script est prévu pour Debian 12."

mkdir -p /etc/emplettes && chmod 700 /etc/emplettes
[ -f "$CONF" ] && . "$CONF"

vert "1/10 Vos réponses"
ADMIN="${ADMIN:-${SUDO_USER:-debian}}"
demander DOMAINE "Nom de domaine" "emplettes.eu"
demander COURRIEL "Votre adresse mail (avis de Let's Encrypt)" "${COURRIEL:-}"
demander ADMIN "Votre compte d'administration sur ce serveur" "$ADMIN"
demander MQTT_UTILISATEUR "Compte de l'application pour le partage (secret GitHub MQTT_UTILISATEUR_VPS)" "${MQTT_UTILISATEUR:-emplettes}"
demander MAIL_COMPTE "Boîte mail d'envoi (compte Zimbra)" "${MAIL_COMPTE:-listes@$DOMAINE}"
demander SMTP_HOTE "Serveur d'envoi de la boîte mail" "${SMTP_HOTE:-smtp.mail.ovh.net}"
demander SMTP_PORT "Port du serveur d'envoi (465 ou 587)" "${SMTP_PORT:-587}"
id "$ADMIN" >/dev/null 2>&1 || stop "le compte $ADMIN n'existe pas."

CHANGER=o
if [ -s /etc/mosquitto/motsdepasse ] && [ -s /etc/emplettes/relais.env ]; then
  CHANGER=n; demander CHANGER "Changer les mots de passe déjà en place ? (o/n)" "n"
fi
if [ "$CHANGER" = o ]; then
  secret MQTT_MDP "Mot de passe du compte $MQTT_UTILISATEUR (secret GitHub MQTT_MOT_DE_PASSE_VPS)"
  secret MQTT_ADMIN_MDP "Mot de passe du compte « admin » du partage (pour vous seul)"
  secret MAIL_MDP "Mot de passe de la boîte $MAIL_COMPTE"
fi
RELAIS_CLE="${RELAIS_CLE:-$(aleatoire 40)}"

umask 077
cat > "$CONF" <<EOF
DOMAINE='$DOMAINE'
COURRIEL='$COURRIEL'
ADMIN='$ADMIN'
MQTT_UTILISATEUR='$MQTT_UTILISATEUR'
MAIL_COMPTE='$MAIL_COMPTE'
SMTP_HOTE='$SMTP_HOTE'
SMTP_PORT='$SMTP_PORT'
RELAIS_CLE='$RELAIS_CLE'
EOF
umask 022
NOMS=("$DOMAINE" "www.$DOMAINE" "mqtt.$DOMAINE" "ntfy.$DOMAINE")

vert "2/10 Système : mises à jour, outils, fuseau horaire, swap"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get -y -q full-upgrade
apt-get -y -q install ca-certificates curl gnupg jq rsync ufw fail2ban unattended-upgrades \
  nginx certbot mosquitto mosquitto-clients python3 dnsutils
timedatectl set-timezone Europe/Paris || true
if ! swapon --show | grep -q /swapfile; then
  [ -f /swapfile ] || { fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null; }
  swapon /swapfile || true
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

vert "3/10 Sécurité : pare-feu, fail2ban, connexion SSH"
ufw default deny incoming >/dev/null; ufw default allow outgoing >/dev/null
for p in 22/tcp 80/tcp 443/tcp 8883/tcp; do ufw allow "$p" >/dev/null; done
ufw --force enable >/dev/null
cat > /etc/fail2ban/jail.d/emplettes.conf <<'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 5
bantime = 1h
EOF
systemctl enable --now fail2ban >/dev/null 2>&1; systemctl restart fail2ban
CLES_ADMIN="$(getent passwd "$ADMIN" | cut -d: -f6)/.ssh/authorized_keys"
if [ -s "$CLES_ADMIN" ]; then
  cat > /etc/ssh/sshd_config.d/10-emplettes.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
  info "Connexion par clé SSH seulement (mot de passe et root refusés)."
else
  info "ATTENTION : aucune clé SSH pour $ADMIN ; la connexion par mot de passe reste ouverte."
  info "Ajoutez votre clé (voir le guide) puis relancez ce script."
fi

vert "4/10 Comptes : publication depuis GitHub, récupération des sauvegardes"
id deploiement >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploiement
id sauvegarde >/dev/null 2>&1 || useradd --create-home --shell /usr/sbin/nologin sauvegarde
mkdir -p "$SRV/site" /var/www/certbot
chown -R deploiement:deploiement "$SRV"
install -d -m 700 -o deploiement -g deploiement /home/deploiement/.ssh
if [ ! -f /etc/emplettes/deploiement_ed25519 ]; then
  ssh-keygen -q -t ed25519 -N '' -C "github-deploiement@$DOMAINE" -f /etc/emplettes/deploiement_ed25519
fi
RRSYNC=$(command -v rrsync || echo /usr/bin/rrsync)
echo "command=\"$RRSYNC $SRV/site\",restrict $(cat /etc/emplettes/deploiement_ed25519.pub)" > /home/deploiement/.ssh/authorized_keys
chown deploiement:deploiement /home/deploiement/.ssh/authorized_keys; chmod 600 /home/deploiement/.ssh/authorized_keys
install -d -m 750 -o root -g sauvegarde /var/backups/emplettes
install -d -m 700 -o sauvegarde -g sauvegarde /home/sauvegarde/.ssh
touch /home/sauvegarde/.ssh/authorized_keys
chown sauvegarde:sauvegarde /home/sauvegarde/.ssh/authorized_keys; chmod 600 /home/sauvegarde/.ssh/authorized_keys
cat > /etc/ssh/sshd_config.d/20-sauvegarde.conf <<'EOF'
Match User sauvegarde
    ChrootDirectory /var/backups/emplettes
    ForceCommand internal-sftp -R
    AllowTcpForwarding no
    X11Forwarding no
EOF
sshd -t && systemctl reload ssh

vert "5/10 Vérification des adresses du domaine"
IP=$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
info "Adresse de ce serveur : $IP"
MANQUE=0
for n in "${NOMS[@]}"; do
  r=$(dig +short A "$n" @1.1.1.1 | tail -n1)
  if [ "$r" = "$IP" ]; then info "$n → $r : bon"; else info "$n → ${r:-rien} : à créer chez OVH (type A, cible $IP)"; MANQUE=1; fi
done
[ "$MANQUE" = 0 ] || stop "créez les adresses manquantes dans la zone DNS d'OVH, attendez une heure, puis relancez le script."

vert "6/10 Certificats Let's Encrypt"
cat > /etc/nginx/sites-available/emplettes <<EOF
server {
    listen 80; listen [::]:80;
    server_name ${NOMS[*]};
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://\$host\$request_uri; }
}
EOF
ln -sf /etc/nginx/sites-available/emplettes /etc/nginx/sites-enabled/emplettes
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
ARGS=(); for n in "${NOMS[@]}"; do ARGS+=(-d "$n"); done
certbot certonly --webroot -w /var/www/certbot --cert-name "$DOMAINE" "${ARGS[@]}" \
  --non-interactive --agree-tos -m "$COURRIEL" --keep-until-expiring --expand
CERT=/etc/letsencrypt/live/$DOMAINE
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/emplettes.sh <<EOF
#!/bin/sh
# Après chaque renouvellement : copie pour Mosquitto, puis relance de Mosquitto et de Nginx.
install -m 640 -o root -g mosquitto $CERT/fullchain.pem /etc/mosquitto/certs/fullchain.pem
install -m 640 -o root -g mosquitto $CERT/privkey.pem /etc/mosquitto/certs/privkey.pem
systemctl restart mosquitto
systemctl reload nginx
EOF
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/emplettes.sh

vert "7/10 Partage : Mosquitto"
install -d -m 750 -o root -g mosquitto /etc/mosquitto/certs
install -m 640 -o root -g mosquitto "$CERT/fullchain.pem" /etc/mosquitto/certs/fullchain.pem
install -m 640 -o root -g mosquitto "$CERT/privkey.pem" /etc/mosquitto/certs/privkey.pem
if [ "$CHANGER" = o ]; then
  rm -f /etc/mosquitto/motsdepasse
  touch /etc/mosquitto/motsdepasse
  mosquitto_passwd -b /etc/mosquitto/motsdepasse "$MQTT_UTILISATEUR" "$MQTT_MDP"
  mosquitto_passwd -b /etc/mosquitto/motsdepasse admin "$MQTT_ADMIN_MDP"
fi
chown mosquitto:mosquitto /etc/mosquitto/motsdepasse; chmod 600 /etc/mosquitto/motsdepasse
cat > /etc/mosquitto/acl <<EOF
# L'application n'écrit et ne lit que sous ldc/ ; le compte admin voit tout.
user $MQTT_UTILISATEUR
topic readwrite ldc/#
user admin
topic readwrite #
EOF
chown mosquitto:mosquitto /etc/mosquitto/acl; chmod 600 /etc/mosquitto/acl
cat > /etc/mosquitto/conf.d/emplettes.conf <<'EOF'
# Emplettes : pas d'accès anonyme, sessions gardées 60 jours, messages retenus sans limite de nombre.
per_listener_settings false
allow_anonymous false
password_file /etc/mosquitto/motsdepasse
acl_file /etc/mosquitto/acl
persistent_client_expiration 60d
max_queued_messages 5000
message_size_limit 2000000
autosave_interval 300
max_connections 5000

# Application Android et Windows
listener 8883
certfile /etc/mosquitto/certs/fullchain.pem
keyfile /etc/mosquitto/certs/privkey.pem

# Navigateur : WebSocket local, ouvert au public par Nginx (wss://mqtt.<domaine>/mqtt)
listener 9001 127.0.0.1
protocol websockets
EOF
systemctl enable mosquitto >/dev/null 2>&1; systemctl restart mosquitto

vert "8/10 Notifications : ntfy"
if ! command -v ntfy >/dev/null; then
  install -d -m 755 /etc/apt/keyrings
  curl -fsSL https://archive.heckel.io/apt/pubkey.txt | gpg --dearmor --yes -o /etc/apt/keyrings/archive.heckel.io.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/archive.heckel.io.gpg] https://archive.heckel.io/apt debian main" \
    > /etc/apt/sources.list.d/archive.heckel.io.list
  apt-get update -q && apt-get -y -q install ntfy
fi
install -d -m 750 -o ntfy -g ntfy /var/cache/ntfy /var/lib/ntfy
WEBPUSH=""
[ -s /etc/emplettes/ntfy-webpush.yml ] || ntfy webpush keys 2>&1 | grep -E '^web-push-(public|private)-key:' > /etc/emplettes/ntfy-webpush.yml || true
if [ "$(grep -c '^web-push-' /etc/emplettes/ntfy-webpush.yml 2>/dev/null)" = 2 ]; then
  WEBPUSH="$(cat /etc/emplettes/ntfy-webpush.yml)
web-push-file: \"/var/lib/ntfy/webpush.db\"
web-push-email-address: \"$COURRIEL\""
fi
cat > /etc/ntfy/server.yml <<EOF
# ntfy d'Emplettes (https://ntfy.$DOMAINE) : messages gardés 48 h, pas de pièces jointes.
base-url: "https://ntfy.$DOMAINE"
listen-http: "127.0.0.1:2586"
behind-proxy: true
cache-file: "/var/cache/ntfy/cache.db"
cache-duration: "48h"
upstream-base-url: "https://ntfy.sh"
visitor-request-limit-burst: 60
visitor-request-limit-replenish: "5s"
visitor-message-daily-limit: 2000
$WEBPUSH
EOF
systemctl enable ntfy >/dev/null 2>&1; systemctl restart ntfy

vert "9/10 Relais de mails, site web, sauvegardes"
install -d -m 755 /opt/emplettes
curl -fsSL "$SOURCE/relais_mail.py" -o /opt/emplettes/relais_mail.py
if [ "$CHANGER" = o ] || [ ! -s /etc/emplettes/relais.env ]; then
  umask 077
  cat > /etc/emplettes/relais.env <<EOF
CLE=$RELAIS_CLE
SMTP_HOTE=$SMTP_HOTE
SMTP_PORT=$SMTP_PORT
SMTP_UTILISATEUR=$MAIL_COMPTE
SMTP_MOT_DE_PASSE=$MAIL_MDP
EXPEDITEUR=$MAIL_COMPTE
ORIGINES=https://$DOMAINE https://christianfrench.github.io
EOF
  umask 022
fi
cat > /etc/systemd/system/relais-mail.service <<'EOF'
[Unit]
Description=Relais de mails d'Emplettes
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=/etc/emplettes/relais.env
ExecStart=/usr/bin/python3 /opt/emplettes/relais_mail.py
DynamicUser=yes
Restart=always
RestartSec=5
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable relais-mail >/dev/null 2>&1; systemctl restart relais-mail

# Les services repartent seuls s'ils s'arrêtent.
for s in mosquitto ntfy nginx; do
  mkdir -p /etc/systemd/system/$s.service.d
  printf '[Service]\nRestart=always\nRestartSec=5\n' > /etc/systemd/system/$s.service.d/relance.conf
done
systemctl daemon-reload

ENTETES='add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;'
SSL="ssl_certificate $CERT/fullchain.pem;
    ssl_certificate_key $CERT/privkey.pem;"
cat > /etc/nginx/sites-available/emplettes <<EOF
# Emplettes : site, application web, démonstration, téléchargements, partage du navigateur, ntfy, relais de mails.
map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }

server {
    listen 80; listen [::]:80;
    server_name ${NOMS[*]};
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://\$host\$request_uri; }
}

server {
    listen 443 ssl http2; listen [::]:443 ssl http2;
    server_name www.$DOMAINE;
    $SSL
    return 301 https://$DOMAINE\$request_uri;
}

server {
    listen 443 ssl http2; listen [::]:443 ssl http2;
    server_name $DOMAINE;
    $SSL
    $ENTETES
    root $SRV/site;
    index index.html;
    gzip on;
    gzip_types text/css application/javascript application/json application/wasm image/svg+xml;
    location ~ \.wasm\$ { types { application/wasm wasm; } $ENTETES add_header Cache-Control "no-cache"; }
    location ~* \.(html|js|json)\$ { $ENTETES add_header Cache-Control "no-cache"; }
    location /telechargements/ { $ENTETES add_header Cache-Control "no-cache"; }
    location = /api/mail/etat { proxy_pass http://127.0.0.1:8025; }
    location = /api/mail {
        client_max_body_size 600k;
        proxy_pass http://127.0.0.1:8025;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    location / { try_files \$uri \$uri/ =404; }
}

server {
    listen 443 ssl http2; listen [::]:443 ssl http2;
    server_name mqtt.$DOMAINE;
    $SSL
    location /mqtt {
        proxy_pass http://127.0.0.1:9001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_read_timeout 1h; proxy_send_timeout 1h;
    }
    location / { return 404; }
}

server {
    listen 443 ssl http2; listen [::]:443 ssl http2;
    server_name ntfy.$DOMAINE;
    $SSL
    client_max_body_size 64k;
    location / {
        proxy_pass http://127.0.0.1:2586;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_connect_timeout 3m; proxy_send_timeout 3m; proxy_read_timeout 3m;
    }
}
EOF
[ -f "$SRV/site/index.html" ] || cat > "$SRV/site/index.html" <<'EOF'
<!doctype html><meta charset="utf-8"><title>Emplettes</title><p>Emplettes : le site arrive à la prochaine compilation.</p>
EOF
chown -R deploiement:deploiement "$SRV"
nginx -t && systemctl reload nginx

cat > /usr/local/sbin/emplettes-sauvegarde <<'EOF'
#!/bin/sh
# Sauvegarde de nuit d'Emplettes : mémoire du partage, réglages, certificats ; gardée 14 jours.
set -e
D=/var/backups/emplettes
F=$D/emplettes-$(date +%F).tar.gz
tar -czf "$F" --ignore-failed-read /var/lib/mosquitto /etc/mosquitto /etc/ntfy /var/cache/ntfy \
  /etc/emplettes /etc/nginx/sites-available/emplettes /etc/letsencrypt 2>/dev/null
chown root:sauvegarde "$F"; chmod 640 "$F"
find "$D" -name 'emplettes-*.tar.gz' -mtime +14 -delete
EOF
chmod 755 /usr/local/sbin/emplettes-sauvegarde
cat > /etc/systemd/system/emplettes-sauvegarde.service <<'EOF'
[Unit]
Description=Sauvegarde de nuit d'Emplettes
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/emplettes-sauvegarde
EOF
cat > /etc/systemd/system/emplettes-sauvegarde.timer <<'EOF'
[Unit]
Description=Sauvegarde de nuit d'Emplettes (3 h)
[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload; systemctl enable --now emplettes-sauvegarde.timer >/dev/null 2>&1

vert "10/10 Vérifications"
ok() { printf '   \033[32mbon\033[0m  %s\n' "$1"; }
ko() { printf '   \033[31mÉCHEC\033[0m %s\n' "$1"; }
for s in nginx mosquitto ntfy relais-mail fail2ban; do systemctl is-active --quiet "$s" && ok "service $s" || ko "service $s (journalctl -u $s)"; done
curl -fsS -o /dev/null "https://$DOMAINE/" && ok "site https://$DOMAINE" || ko "site https://$DOMAINE"
curl -fsS "https://ntfy.$DOMAINE/v1/health" | grep -q true && ok "ntfy https://ntfy.$DOMAINE" || ko "ntfy"
curl -fsS "https://$DOMAINE/api/mail/etat" | grep -q true && ok "relais de mails" || ko "relais de mails"
if [ "$CHANGER" = o ]; then
  if timeout 15 mosquitto_sub -h "mqtt.$DOMAINE" -p 8883 --capath /etc/ssl/certs -u "$MQTT_UTILISATEUR" -P "$MQTT_MDP" \
       -t 'ldc/essai-installation' -C 1 -W 10 >/tmp/essai-mqtt 2>&1 & sleep 2
     mosquitto_pub -h "mqtt.$DOMAINE" -p 8883 --capath /etc/ssl/certs -u "$MQTT_UTILISATEUR" -P "$MQTT_MDP" -t 'ldc/essai-installation' -m bonjour
     wait; grep -q bonjour /tmp/essai-mqtt; then ok "partage mqtt.$DOMAINE:8883 (TLS, mot de passe)"; else ko "partage mqtt.$DOMAINE:8883"; fi
  rm -f /tmp/essai-mqtt
fi

vert "Terminé. À saisir dans GitHub (Settings › Secrets and variables › Actions)"
cat <<EOF
   MQTT_HOTE_VPS          mqtt.$DOMAINE
   MQTT_UTILISATEUR_VPS   $MQTT_UTILISATEUR
   MQTT_MOT_DE_PASSE_VPS  (le mot de passe choisi pour $MQTT_UTILISATEUR)
   RELAIS_CLE             $RELAIS_CLE
   VPS_HOTE               $DOMAINE
   VPS_CLE_DEPLOIEMENT    la clé ci-dessous, en entier, lignes BEGIN et END comprises :
EOF
cat /etc/emplettes/deploiement_ed25519
echo
info "Ces valeurs restent dans /etc/emplettes (root seul). Ne les envoyez à personne, pas même à Claude."
