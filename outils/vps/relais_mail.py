#!/usr/bin/env python3
"""Relais de mails d'Emplettes (VPS, derrière Nginx : https://<domaine>/api/mail).

Remplace EmailJS : l'application envoie les mêmes champs (destinataires, sujet, texte, texte_html,
expediteur, repondre_a) et le relais les envoie par la boîte mail du domaine (Zimbra OVH), en SMTP.
Le mot de passe de la boîte reste sur le VPS (/etc/emplettes/relais.env, lisible par root seulement).

Garde-fous : clé de l'application exigée, 10 destinataires au plus, nombre d'envois limité par adresse IP
et par jour, journal des envois sans leur contenu. Python 3.11 de Debian 12, sans bibliothèque à ajouter.
"""
import datetime
import hmac
import json
import os
import re
import smtplib
import ssl
import sys
import threading
from email.message import EmailMessage
from email.utils import formataddr, make_msgid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CLE = os.environ.get('CLE', '')
SMTP_HOTE = os.environ.get('SMTP_HOTE', 'smtp.mail.ovh.net')
SMTP_PORT = int(os.environ.get('SMTP_PORT', '587'))
SMTP_UTILISATEUR = os.environ.get('SMTP_UTILISATEUR', '')
SMTP_MOT_DE_PASSE = os.environ.get('SMTP_MOT_DE_PASSE', '')
EXPEDITEUR = os.environ.get('EXPEDITEUR', SMTP_UTILISATEUR)
ORIGINES = [o for o in os.environ.get('ORIGINES', '').split() if o]
PAR_IP_ET_JOUR = int(os.environ.get('PAR_IP_ET_JOUR', '40'))
PAR_JOUR = int(os.environ.get('PAR_JOUR', '1000'))
ECOUTE = ('127.0.0.1', int(os.environ.get('PORT', '8025')))

ADRESSE = re.compile(r'^[^@\s<>,;"]+@[^@\s<>,;"]+\.[^@\s<>,;"]+$')
_verrou = threading.Lock()
_compteurs = {'jour': '', 'total': 0, 'ip': {}}


def journal(texte):
    print(f'{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {texte}', flush=True)


def compter(ip):
    """True si cette adresse peut encore envoyer aujourd'hui (et compte l'envoi)."""
    with _verrou:
        jour = datetime.date.today().isoformat()
        if _compteurs['jour'] != jour:
            _compteurs.update(jour=jour, total=0, ip={})
        n = _compteurs['ip'].get(ip, 0)
        if n >= PAR_IP_ET_JOUR or _compteurs['total'] >= PAR_JOUR:
            return False
        _compteurs['ip'][ip] = n + 1
        _compteurs['total'] += 1
        return True


def envoyer(p):
    a = [x.strip() for x in str(p.get('destinataires', '')).split(',') if x.strip()]
    if not a or len(a) > 10 or not all(ADRESSE.match(x) for x in a):
        raise ValueError('destinataires invalides (1 à 10 adresses)')
    sujet = str(p.get('sujet', ''))[:200].replace('\n', ' ')
    texte = str(p.get('texte', ''))[:100_000]
    html = str(p.get('texte_html', ''))[:300_000]
    nom = str(p.get('expediteur', '') or 'Emplettes')[:60].replace('\n', ' ')
    repondre = str(p.get('repondre_a', '')).strip()
    m = EmailMessage()
    m['From'] = formataddr((f'{nom} · Emplettes' if nom != 'Emplettes' else nom, EXPEDITEUR))
    m['To'] = ', '.join(a)
    m['Subject'] = sujet or 'Emplettes'
    m['Message-ID'] = make_msgid(domain=EXPEDITEUR.split('@')[-1])
    if ADRESSE.match(repondre):
        m['Reply-To'] = repondre
    m.set_content(texte or re.sub(r'<[^>]+>', '', html) or ' ')
    if html:
        m.add_alternative(html, subtype='html')
    contexte = ssl.create_default_context()
    if SMTP_PORT == 465:
        with smtplib.SMTP_SSL(SMTP_HOTE, SMTP_PORT, context=contexte, timeout=30) as s:
            s.login(SMTP_UTILISATEUR, SMTP_MOT_DE_PASSE)
            s.send_message(m)
    else:
        with smtplib.SMTP(SMTP_HOTE, SMTP_PORT, timeout=30) as s:
            s.starttls(context=contexte)
            s.login(SMTP_UTILISATEUR, SMTP_MOT_DE_PASSE)
            s.send_message(m)
    return len(a)


class Relais(BaseHTTPRequestHandler):
    server_version = 'relais-mail'

    def _repondre(self, code, corps):
        donnees = json.dumps(corps, ensure_ascii=False).encode()
        self.send_response(code)
        origine = self.headers.get('Origin', '')
        if origine in ORIGINES:
            self.send_header('Access-Control-Allow-Origin', origine)
            self.send_header('Vary', 'Origin')
            self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(donnees)))
        self.end_headers()
        self.wfile.write(donnees)

    def log_message(self, *args):  # pas de journal par requête : seulement les envois
        pass

    def do_OPTIONS(self):
        self._repondre(204, {})

    def do_GET(self):
        if self.path.rstrip('/') == '/api/mail/etat':
            self._repondre(200, {'ok': True, 'aujourdhui': _compteurs['total']})
        else:
            self._repondre(404, {'ok': False})

    def do_POST(self):
        if self.path.rstrip('/') != '/api/mail':
            return self._repondre(404, {'ok': False})
        ip = self.headers.get('X-Real-IP', self.client_address[0])
        try:
            n = int(self.headers.get('Content-Length', '0'))
            if n > 512_000:
                return self._repondre(413, {'ok': False, 'erreur': 'trop grand'})
            corps = json.loads(self.rfile.read(n) or b'{}')
        except Exception:
            return self._repondre(400, {'ok': False, 'erreur': 'JSON invalide'})
        cle = str(corps.get('cle') or corps.get('user_id') or '')
        if not CLE or not hmac.compare_digest(cle, CLE):
            journal(f'refusé (clé) {ip}')
            return self._repondre(403, {'ok': False, 'erreur': 'clé refusée'})
        if not compter(ip):
            journal(f'refusé (limite du jour) {ip}')
            return self._repondre(429, {'ok': False, 'erreur': 'limite du jour atteinte'})
        try:
            nb = envoyer(corps.get('template_params') or corps)
            journal(f'envoyé à {nb} destinataire(s) {ip}')
            self._repondre(200, {'ok': True})
        except ValueError as e:
            self._repondre(400, {'ok': False, 'erreur': str(e)})
        except Exception as e:  # SMTP : on renvoie la cause, l'application retombe sur la messagerie
            journal(f'échec SMTP {type(e).__name__}: {e} {ip}')
            self._repondre(502, {'ok': False, 'erreur': f'envoi impossible : {type(e).__name__}'})


if __name__ == '__main__':
    if not (CLE and SMTP_UTILISATEUR and SMTP_MOT_DE_PASSE):
        sys.exit('relais-mail : CLE, SMTP_UTILISATEUR et SMTP_MOT_DE_PASSE sont nécessaires (/etc/emplettes/relais.env)')
    journal(f'relais-mail à l\'écoute sur {ECOUTE[0]}:{ECOUTE[1]}, envoi par {SMTP_HOTE}:{SMTP_PORT}')
    ThreadingHTTPServer(ECOUTE, Relais).serve_forever()
