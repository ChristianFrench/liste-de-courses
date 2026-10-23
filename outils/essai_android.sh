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
printf '%%PDF-1.4\n%%essai\n' > ticket.pdf
adb push ticket.pdf /data/local/tmp/ticket.pdf
adb shell chmod 644 /data/local/tmp/ticket.pdf
echo "::warning title=Applications pour un PDF partagé::$(adb shell pm query-activities -a android.intent.action.SEND -t application/pdf 2>&1 | grep -oE 'packageName=[^ ]+' | sort -u | paste -sd'|')"
adb shell am start -a android.intent.action.VIEW -d file:///data/local/tmp/ticket.pdf -t application/pdf -n $APP/.MainActivity
sleep 8
adb shell uiautomator dump /sdcard/ecran2.xml
adb pull /sdcard/ecran2.xml ecran2.xml
textes=$(grep -oE '(text|content-desc)="[^"]+"' ecran2.xml | sed -E 's/^[^"]*"//; s/"$//' | head -n 40 | paste -sd'|')
echo "::warning title=Ticket reçu::${textes:-aucun texte lisible}"
exit 0
