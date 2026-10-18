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
exit 0
