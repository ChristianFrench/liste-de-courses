"""Diagnostic du serveur MQTT (lancé par .github/workflows/diagnostic-mqtt.yml).

Se connecte comme le web (WebSocket 8084, /mqtt) puis comme l'exe (8883), s'abonne au canal du foyer
et liste ce qui arrive : sujet, taille, retenu, JSON lisible. N'affiche jamais le contenu des listes.
"""
import json
import os
import ssl
import sys
import time

import paho.mqtt.client as mqtt

HOTE = 'w041270a.ala.us-east-1.emqxsl.com'
canal = sys.argv[1]


def essai(transport, port):
    recus = []
    c = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f'ldc-diagnostic-{transport}-{int(time.time())}',
                    clean_session=True, transport=transport)
    if transport == 'websockets':
        c.ws_set_options(path='/mqtt')
    c.tls_set(cert_reqs=ssl.CERT_REQUIRED)
    c.username_pw_set(os.environ['MQTT_UTILISATEUR'], os.environ['MQTT_MOT_DE_PASSE'])
    etat = {}

    def connecte(cl, u, f, rc, p=None):
        etat['connexion'] = str(rc)
        cl.subscribe(f'ldc/{canal}/#', qos=1)

    def abonne(cl, u, mid, rcs, p=None):
        etat['abonnement'] = [str(r) for r in rcs]
        cl.publish(f'ldc/{canal}/controle/diagnostic', json.dumps({'de': 'diagnostic', 't': 1}), qos=1)

    def message(cl, u, m):
        try:
            texte = m.payload.decode('utf-8')
            lisible = 'json' if not texte or isinstance(json.loads(texte), dict) else 'autre'
        except Exception as e:  # noqa
            lisible = f'ILLISIBLE ({type(e).__name__})'
        recus.append((m.topic, len(m.payload), m.retain, lisible))

    c.on_connect, c.on_subscribe, c.on_message = connecte, abonne, message
    print(f'== {transport} port {port}')
    c.connect(HOTE, port, keepalive=30)
    c.loop_start()
    time.sleep(15)
    c.loop_stop()
    c.disconnect()
    types = {}
    for t, n, r, l in recus:
        k = t.split('/')[2] if t.count('/') >= 2 else t
        nb, mx = types.get(k, (0, 0))
        types[k] = (nb + 1, max(mx, n))
    print(f'::notice title={transport}::connexion={etat.get("connexion")} abonnement={etat.get("abonnement")} messages={len(recus)}'
          f' controle revenu={"oui" if any(t.endswith("/controle/diagnostic") for t, *_ in recus) else "NON"}'
          f' types={types}')
    for t, n, r, l in recus:
        if n > 30000 or l != 'json':
            print(f'::notice title={transport} message particulier::{t} {n} octets retenu={int(r)} {l}')


essai('websockets', 8084)
essai('tcp', 8883)
