# Ajoute au projet Android créé par « flutter create » le widget d'écran d'accueil du mémo.
import pathlib, shutil
ici = pathlib.Path(__file__).parent
app = pathlib.Path('android/app/src/main')
kt = app / 'kotlin/fr/listecourses/memo_emplettes'
kt.mkdir(parents=True, exist_ok=True)
for f in (ici / 'kotlin').glob('*.kt'):
    shutil.copy(f, kt / f.name)
for d in ('layout', 'xml', 'drawable'):
    (app / 'res' / d).mkdir(parents=True, exist_ok=True)
    for f in (ici / 'res' / d).glob('*.xml'):
        shutil.copy(f, app / 'res' / d / f.name)
(app / 'res/values').mkdir(parents=True, exist_ok=True)
(app / 'res/values/memo.xml').write_text('<resources><string name="app_name">Mémo Emplettes</string></resources>\n')
m = app / 'AndroidManifest.xml'
t = m.read_text()
t = t.replace('android:label="memo_emplettes"', 'android:label="Mémo Emplettes"')
t = t.replace('</application>', '''    <receiver android:name=".MemoWidget" android:exported="true" android:label="Mémo Emplettes">
            <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/memo_widget_info" />
        </receiver>
        <activity android:name=".Relais" android:exported="false" android:theme="@android:style/Theme.NoDisplay"
            android:excludeFromRecents="true" android:noHistory="true" android:taskAffinity="" />
        <service android:name=".MemoService" android:permission="android.permission.BIND_REMOTEVIEWS" android:exported="false" />
    </application>''', 1)
m.write_text(t)
print('widget ajouté')

# Toujours la même clé de signature (celle d'Emplettes, outils/android/debug.keystore) : sans elle, chaque
# compilation a une clé neuve et Android refuse d'installer la nouvelle version par-dessus l'ancienne.
g = pathlib.Path('android/app/build.gradle.kts')
t = g.read_text()
t = t.replace('''    buildTypes {
        release {''', '''    signingConfigs {
        create("memo") {
            storeFile = rootProject.file("../../android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {''', 1)
assert 'signingConfigs.getByName("debug")' in t
t = t.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("memo")', 1)
g.write_text(t)
print('signature fixe')
