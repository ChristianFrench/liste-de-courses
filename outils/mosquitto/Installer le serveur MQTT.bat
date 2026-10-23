@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title Serveur MQTT pour Liste de courses
rem ==========================================================================================
rem  Installe et configure Mosquitto (serveur MQTT) sur ce PC pour la synchronisation
rem  de Liste de courses, puis vérifie le serveur avec Verifier-serveur-MQTT.exe.
rem
rem  Double-clic : les questions sont posées à l'écran.
rem  Sans question : "Installer le serveur MQTT.bat" identifiant motdepasse [port]
rem  Peut être relancé sans risque (changer de mot de passe, de port...).
rem ==========================================================================================

rem --- Droits administrateur (installation, service, pare-feu)
net session >nul 2>&1
if not errorlevel 1 goto admin
echo Droits administrateur nécessaires : Windows va demander l'autorisation.
if "%~1"=="" (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
) else (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
)
exit /b

:admin
set "ICI=%~dp0"
set "MOSQ=%ProgramFiles%\mosquitto"
set "DONNEES=%ProgramData%\ListeDeCourses-MQTT"
set "UTIL=%~1"
set "MDP=%~2"
set "PORT=%~3"
set "AUTO="
if not "%UTIL%"=="" set "AUTO=1"
if "%PORT%"=="" set "PORT=1883"

echo.
echo  Serveur MQTT pour Liste de courses
echo  ==================================
echo.
if defined AUTO goto choixfaits
set /p "UTIL=Identifiant des appareils [courses] : "
if "%UTIL%"=="" set "UTIL=courses"
echo Mot de passe : lettres et chiffres seulement. Laissez vide pour en tirer un au hasard.
set /p "MDP=Mot de passe : "
set /p "PORT=Port [1883] : "
if "%PORT%"=="" set "PORT=1883"

:choixfaits
if "%MDP%"=="" for /f "delims=" %%p in ('powershell -NoProfile -Command "-join ((48..57)+(65..90)+(97..122) | Get-Random -Count 12 | ForEach-Object {[char]$_})"') do set "MDP=%%p"
echo %UTIL%| findstr /r /x "[A-Za-z0-9_-]*" >nul || (echo Identifiant refusé : lettres, chiffres, - et _ seulement. & goto echec)
echo %MDP%| findstr /r /x "[A-Za-z0-9_-]*" >nul || (echo Mot de passe refusé : lettres, chiffres, - et _ seulement. & goto echec)
echo %PORT%| findstr /r /x "[0-9][0-9]*" >nul || (echo Port refusé : un nombre, par exemple 1883. & goto echec)

rem --- 1. Installation de Mosquitto
echo.
echo [1/6] Mosquitto
if exist "%MOSQ%\mosquitto.exe" (
  echo       déjà installé dans %MOSQ%
  goto installe
)
where winget >nul 2>&1 && (
  echo       installation par winget...
  winget install -e --id EclipseFoundation.Mosquitto --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
)
if exist "%MOSQ%\mosquitto.exe" goto installe
echo       téléchargement depuis mosquitto.org...
set "PROG=%TEMP%\mosquitto-installation.exe"
if exist "%PROG%" del "%PROG%"
for %%V in (2.0.22 2.0.21 2.0.20 2.0.18) do (
  if not exist "%PROG%" curl -fsSL -o "%PROG%" https://mosquitto.org/files/binary/win64/mosquitto-%%V-install-windows-x64.exe
)
if not exist "%PROG%" (echo       Téléchargement impossible : vérifiez la connexion à Internet. & goto echec)
echo       installation...
start "" /wait "%PROG%" /S
del "%PROG%"
if not exist "%MOSQ%\mosquitto.exe" (echo       L'installation de Mosquitto a échoué. & goto echec)
:installe
echo       ok

rem --- 2. Identifiant, mot de passe et droits : les appareils n'ont accès qu'aux sujets ldc/...
echo [2/6] Identifiant et droits d'accès
if not exist "%DONNEES%" mkdir "%DONNEES%"
if exist "%DONNEES%\passwd" del "%DONNEES%\passwd"
"%MOSQ%\mosquitto_passwd.exe" -c -b "%DONNEES%\passwd" %UTIL% %MDP%
if errorlevel 1 (echo       Création du mot de passe impossible. & goto echec)
> "%DONNEES%\acl" echo user %UTIL%
>> "%DONNEES%\acl" echo topic readwrite ldc/#
echo       ok : %UTIL%, sujets ldc/#

rem --- 3. Configuration (l'ancienne est gardée une fois sous mosquitto.conf.origine)
echo [3/6] Configuration
if exist "%MOSQ%\mosquitto.conf" if not exist "%MOSQ%\mosquitto.conf.origine" copy "%MOSQ%\mosquitto.conf" "%MOSQ%\mosquitto.conf.origine" >nul
> "%MOSQ%\mosquitto.conf" echo # Liste de courses : configuration ecrite par Installer le serveur MQTT.bat
>> "%MOSQ%\mosquitto.conf" echo listener %PORT%
>> "%MOSQ%\mosquitto.conf" echo allow_anonymous false
>> "%MOSQ%\mosquitto.conf" echo password_file %DONNEES%\passwd
>> "%MOSQ%\mosquitto.conf" echo acl_file %DONNEES%\acl
>> "%MOSQ%\mosquitto.conf" echo # Messages gardes pour les appareils hors ligne, et sur disque au redemarrage
>> "%MOSQ%\mosquitto.conf" echo persistence true
>> "%MOSQ%\mosquitto.conf" echo persistence_location %DONNEES%\
>> "%MOSQ%\mosquitto.conf" echo autosave_interval 60
>> "%MOSQ%\mosquitto.conf" echo persistent_client_expiration 90d
>> "%MOSQ%\mosquitto.conf" echo max_queued_messages 10000
>> "%MOSQ%\mosquitto.conf" echo log_dest file %DONNEES%\mosquitto.log
>> "%MOSQ%\mosquitto.conf" echo log_type error
>> "%MOSQ%\mosquitto.conf" echo log_type warning
>> "%MOSQ%\mosquitto.conf" echo log_type notice
>> "%MOSQ%\mosquitto.conf" echo connection_messages true
echo       ok : %MOSQ%\mosquitto.conf, port %PORT%

rem --- 4. Service Windows : démarre avec le PC
echo [4/6] Service Windows
sc query mosquitto >nul 2>&1 || "%MOSQ%\mosquitto.exe" install
sc config mosquitto start= auto >nul
net stop mosquitto >nul 2>&1
net start mosquitto >nul 2>&1
sc query mosquitto | findstr /c:"RUNNING" >nul || (echo       Le service ne démarre pas : voir %DONNEES%\mosquitto.log & goto echec)
echo       ok : service mosquitto démarré, démarrage automatique

rem --- 5. Pare-feu : le port est ouvert pour les réseaux privés (maison)
echo [5/6] Pare-feu
netsh advfirewall firewall delete rule name="Mosquitto MQTT - Liste de courses" >nul 2>&1
netsh advfirewall firewall add rule name="Mosquitto MQTT - Liste de courses" dir=in action=allow protocol=TCP localport=%PORT% profile=private,domain >nul
echo       ok : port %PORT% ouvert sur les réseaux privés
powershell -NoProfile -Command "if (Get-NetConnectionProfile | Where-Object NetworkCategory -eq 'Public') { exit 1 }" && goto reseauok
echo       ATTENTION : le réseau de ce PC est déclaré « public » : les téléphones ne pourront pas joindre le serveur.
if defined AUTO goto reseauok
set "REP="
set /p "REP=      Déclarer ce réseau comme privé (réseau de la maison) ? (o/n) [o] : "
if /i "%REP%"=="n" goto reseauok
powershell -NoProfile -Command "Get-NetConnectionProfile | Where-Object NetworkCategory -eq 'Public' | Set-NetConnectionProfile -NetworkCategory Private"
echo       ok : réseau déclaré privé
:reseauok

rem --- 6. Réglages pour l'application, puis vérification
echo [6/6] Réglages à saisir dans l'application
set "ADRESSES="
for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }).IPAddress -join '  ou  '"') do set "ADRESSES=%%a"
set "REGLAGES=%ICI%Reglages du serveur MQTT.txt"
> "%REGLAGES%" echo Liste de courses : Gérer ^> Mon foyer ^> Partage entre appareils ^> Serveur MQTT
>> "%REGLAGES%" echo.
>> "%REGLAGES%" echo   Adresse du serveur : %ADRESSES%
>> "%REGLAGES%" echo   Port : %PORT%
>> "%REGLAGES%" echo   Connexion chiffrée TLS : décochée
>> "%REGLAGES%" echo   Identifiant : %UTIL%
>> "%REGLAGES%" echo   Mot de passe : %MDP%
>> "%REGLAGES%" echo.
>> "%REGLAGES%" echo Le téléphone doit être sur le Wi-Fi de la maison, le PC allumé.
type "%REGLAGES%"
echo.
echo   Ces réglages sont gardés dans "%REGLAGES%"
echo.

set "VERIF=%ICI%Verifier-serveur-MQTT.exe"
if not exist "%VERIF%" goto fin
echo Vérification du serveur...
echo.
if defined AUTO (
  "%VERIF%" --hote 127.0.0.1 --port %PORT% --utilisateur %UTIL% --mot-de-passe %MDP% --sans-pause
) else (
  "%VERIF%" --hote 127.0.0.1 --port %PORT% --utilisateur %UTIL% --mot-de-passe %MDP%
)
if errorlevel 1 goto echec

:fin
echo.
echo Serveur MQTT prêt.
if not defined AUTO pause
exit /b 0

:echec
echo.
echo Mise en place interrompue.
if not defined AUTO pause
exit /b 1
