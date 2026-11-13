#!/bin/bash
# Essai de l'APK sur l'émulateur (appelé par .github/workflows/essai-android.yml).
# Les résultats sont rendus en annotations, lisibles par l'API GitHub.
APP=fr.listecourses.liste_de_courses
adb install -r app.apk
adb logcat -c
adb shell monkey -p $APP -c android.intent.category.LAUNCHER 1
sleep 45
adb exec-out screencap -p > capture.png
adb logcat -d > logcat.txt
adb shell uiautomator dump /sdcard/ecran.xml
adb pull /sdcard/ecran.xml ecran.xml
textes=$(grep -oE '(text|content-desc)="[^"]+"' ecran.xml | sed -E 's/^[^"]*"//; s/"$//' | head -n 80 | paste -sd'|')
echo "::warning title=Textes affichés::${textes:-aucun texte lisible}"
echo "::warning title=Activité au premier plan::$(adb shell dumpsys activity activities | grep -m3 -E 'mResumedActivity|mFocusedActivity' | paste -sd'|')"
sed -n '/Calling main entry com.android.commands.monkey/,$p' logcat.txt \
  | grep -E " (I|W|E|F) (flutter|AndroidRuntime|DEBUG|libc) " | cut -c1-220 | head -n 40 > extrait.txt
echo "::warning title=Journal de l'application::$(sed 's/%/%25/g' extrait.txt | paste -sd'|')"

# Ticket de caisse PDF « ouvert avec » l'application (comme depuis les téléchargements)
pip install -q pillow > /dev/null 2>&1
python3 - <<'PY'
# Ticket en image, comme ceux de Leclerc (aucun texte dans le PDF) : l'application doit le signaler (date et prix inconnus)
from PIL import Image, ImageDraw, ImageFont
try:
    police = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 34)
except OSError:
    police = ImageFont.load_default()
lignes = ["E.LECLERC ESSAI", "Ticket 01/10/26 @ 07H06", "", "LAIT DEMI ECREME          1.15", "CAMEMBERT                 2.89",
          "", "Total 12 articles        45.60", "", "CB                       45.60"]
im = Image.new("RGB", (900, 120 + 60 * len(lignes)), "white")
d = ImageDraw.Draw(im)
for i, l in enumerate(lignes):
    d.text((60, 60 + 60 * i), l, fill="black", font=police)
im.save("ticket.pdf", resolution=200)
PY
adb push ticket.pdf /data/local/tmp/ticket.pdf
adb shell chmod 644 /data/local/tmp/ticket.pdf
echo "::warning title=Applications pour un PDF partagé::$(adb shell pm query-activities -a android.intent.action.SEND -t application/pdf 2>&1 | grep -oE 'packageName=[^ ]+' | sort -u | paste -sd'|')"
adb shell am start -a android.intent.action.VIEW -d file:///data/local/tmp/ticket.pdf -t application/pdf -n $APP/.MainActivity
sleep 8
adb shell uiautomator dump /sdcard/ecran2.xml
adb pull /sdcard/ecran2.xml ecran2.xml
textes=$(grep -oE '(text|content-desc)="[^"]+"' ecran2.xml | sed -E 's/^[^"]*"//; s/"$//' | head -n 40 | paste -sd'|')
echo "::warning title=Ticket reçu::${textes:-aucun texte lisible}"

# Touche l'élément dont le texte (ou la description) contient $1 ; rend les textes de l'écran dans $ECRAN.
toucher() {
  adb shell uiautomator dump /sdcard/e.xml > /dev/null; adb pull /sdcard/e.xml e.xml > /dev/null
  xy=$(python3 - "$1" <<'PY'
import re, sys
x = open("e.xml", encoding="utf-8").read()
for n in re.finditer(r'<node [^>]*>', x):
    t = n.group(0)
    if re.search(r'(text|content-desc)="[^"]*' + re.escape(sys.argv[1]), t):
        a, b, c, d = map(int, re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', t).groups())
        print((a + c) // 2, (b + d) // 2); break
PY
)
  [ -n "$xy" ] && adb shell input tap $xy && sleep 3
  echo "${xy:-introuvable}"
}
ecran() { adb shell uiautomator dump /sdcard/e.xml > /dev/null; adb pull /sdcard/e.xml e.xml > /dev/null; grep -oE '(text|content-desc)="[^"]+"' e.xml | sed -E 's/^[^"]*"//; s/"$//' | head -n 40 | paste -sd'|'; }

# Le ticket est gardé sans course, l'application est fermée puis rouverte : il doit être là, et s'ouvrir.
r1=$(toucher "Le garder"); r2=$(toucher "Magasin 1")
sleep 10; adb shell input text Essai; sleep 1
echo "::warning title=Fenêtre du ticket (date et montant lus)::$(ecran)"
r3=$(toucher "Valider")
sleep 2
adb shell am force-stop $APP
adb shell monkey -p $APP -c android.intent.category.LAUNCHER 1 > /dev/null; sleep 20
r4=$(toucher "Gérer"); r5=$(toucher "Historique")
echo "::warning title=Après redémarrage (Gérer › Historique)::$r1 $r2 $r3 $r4 $r5 | $(ecran)"
r6=$(toucher "Tickets non rattachés"); r7=$(toucher "Ouvrir le ticket PDF"); sleep 3
echo "::warning title=Trombone touché::$r6 $r7 | $(ecran) | $(adb shell dumpsys activity activities | grep -m2 -E 'mResumedActivity|topResumedActivity' | paste -sd'|')"
adb logcat -d | grep -E "Lecture ticket|FATAL|Could not instantiate" | grep -v uiautomator | tail -n 12 | cut -c1-220 > err.txt
adb exec-out screencap -p > lecteur.png
echo "::warning title=Erreurs Android::$(paste -sd'|' err.txt)"
exit 0
