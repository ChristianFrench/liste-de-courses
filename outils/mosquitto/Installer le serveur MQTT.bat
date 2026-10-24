@echo off
rem Texte sans accents : cmd.exe lit mal un .bat en UTF-8 sur certains Windows 10 (le script s'arretait).
setlocal EnableExtensions DisableDelayedExpansion
title Serveur MQTT pour Liste de courses
rem ==========================================================================================
rem  Installe et configure Mosquitto (serveur MQTT) sur ce PC pour la synchronisation
rem  de Liste de courses, puis verifie le serveur avec Verifier-serveur-MQTT.exe.
rem
rem  Double-clic : les questions sont posees a l'ecran.
rem  Sans question : "Installer le serveur MQTT.bat" identifiant motdepasse [port]
rem  Peut etre relance sans risque (changer de mot de passe, de port...).
rem ==========================================================================================

rem --- Droits administrateur (installation, service, pare-feu)
net session >nul 2>&1
if not errorlevel 1 goto admin
echo Droits administrateur necessaires : Windows va demander l'autorisation.
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
echo %UTIL%| findstr /r /x "[A-Za-z0-9_-]*" >nul || (echo Identifiant refuse : lettres, chiffres, - et _ seulement. & goto echec)
echo %MDP%| findstr /r /x "[A-Za-z0-9_-]*" >nul || (echo Mot de passe refuse : lettres, chiffres, - et _ seulement. & goto echec)
echo %PORT%| findstr /r /x "[0-9][0-9]*" >nul || (echo Port refuse : un nombre, par exemple 1883. & goto echec)

rem --- 1. Installation de Mosquitto
echo.
echo [1/6] Mosquitto
if exist "%MOSQ%\mosquitto.exe" (
  echo       deja installe dans %MOSQ%
  goto installe
)
where winget >nul 2>&1 && (
  echo       installation par winget...
  winget install -e --id EclipseFoundation.Mosquitto --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
)
if exist "%MOSQ%\mosquitto.exe" goto installe
echo       telechargement depuis mosquitto.org...
set "PROG=%TEMP%\mosquitto-installation.exe"
if exist "%PROG%" del "%PROG%"
for %%V in (2.0.22 2.0.21 2.0.20 2.0.18) do (
  if not exist "%PROG%" curl -fsSL -o "%PROG%" https://mosquitto.org/files/binary/win64/mosquitto-%%V-install-windows-x64.exe
)
if not exist "%PROG%" (echo       Telechargement impossible : verifiez la connexion a Internet. & goto echec)
echo       installation...
start "" /wait "%PROG%" /S
del "%PROG%"
if not exist "%MOSQ%\mosquitto.exe" (echo       L'installation de Mosquitto a echoue. & goto echec)
:installe
echo       ok

rem --- 2. Identifiant, mot de passe et droits : les appareils n'ont acces qu'aux sujets ldc/...
echo [2/6] Identifiant et droits d'acces
if not exist "%DONNEES%" mkdir "%DONNEES%"
if exist "%DONNEES%\passwd" del "%DONNEES%\passwd"
"%MOSQ%\mosquitto_passwd.exe" -c -b "%DONNEES%\passwd" %UTIL% %MDP%
if errorlevel 1 (echo       Creation du mot de passe impossible. & goto echec)
rem Le fichier est reserve a son createur : le service (compte SYSTEM, S-1-5-18) doit pouvoir le lire
icacls "%DONNEES%\passwd" /grant *S-1-5-18:R >nul
> "%DONNEES%\acl" echo user %UTIL%
>> "%DONNEES%\acl" echo topic readwrite ldc/#
echo       ok : %UTIL%, sujets ldc/#

rem --- 3. Configuration (l'ancienne est gardee une fois sous mosquitto.conf.origine)
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

rem --- 4. Service Windows : demarre avec le PC
echo [4/6] Service Windows
sc query mosquitto >nul 2>&1 || "%MOSQ%\mosquitto.exe" install
sc config mosquitto start= auto >nul
net stop mosquitto >nul 2>&1
net start mosquitto >nul 2>&1
set /a ESSAIS=0
:attenteservice
sc query mosquitto | findstr /c:"RUNNING" >nul && goto servicedemarre
set /a ESSAIS+=1
if %ESSAIS% geq 15 goto servicearrete
timeout /t 1 /nobreak >nul 2>&1 || ping -n 2 127.0.0.1 >nul
goto attenteservice
:servicearrete
echo       Le service ne demarre pas. Details :
sc query mosquitto
if exist "%DONNEES%\mosquitto.log" type "%DONNEES%\mosquitto.log"
icacls "%DONNEES%"
icacls "%DONNEES%\*"
echo       Essai de lancement direct :
findstr /v /c:"log_dest" "%MOSQ%\mosquitto.conf" > "%TEMP%\mosquitto-essai.conf"
>> "%TEMP%\mosquitto-essai.conf" echo log_dest stdout
start "" /b "%MOSQ%\mosquitto.exe" -c "%TEMP%\mosquitto-essai.conf" -v
ping -n 4 127.0.0.1 >nul
taskkill /im mosquitto.exe /f >nul 2>&1
goto echec
:servicedemarre
echo       ok : service mosquitto demarre, demarrage automatique

rem --- 5. Pare-feu : le port est ouvert pour les reseaux prives (maison)
echo [5/6] Pare-feu
netsh advfirewall firewall delete rule name="Mosquitto MQTT - Liste de courses" >nul 2>&1
netsh advfirewall firewall add rule name="Mosquitto MQTT - Liste de courses" dir=in action=allow protocol=TCP localport=%PORT% profile=private,domain >nul
echo       ok : port %PORT% ouvert sur les reseaux prives
powershell -NoProfile -Command "if (Get-NetConnectionProfile | Where-Object NetworkCategory -eq 'Public') { exit 1 }" && goto reseauok
echo       ATTENTION : le reseau de ce PC est declare " public " : les telephones ne pourront pas joindre le serveur.
if defined AUTO goto reseauok
set "REP="
set /p "REP=      Declarer ce reseau comme prive (reseau de la maison) ? (o/n) [o] : "
if /i "%REP%"=="n" goto reseauok
powershell -NoProfile -Command "Get-NetConnectionProfile | Where-Object NetworkCategory -eq 'Public' | Set-NetConnectionProfile -NetworkCategory Private"
echo       ok : reseau declare prive
:reseauok

rem --- 6. Reglages pour l'application, puis verification
echo [6/6] Reglages a saisir dans l'application
set "ADRESSES="
for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }).IPAddress -join '  ou  '"') do set "ADRESSES=%%a"
set "REGLAGES=%ICI%Reglages du serveur MQTT.txt"
> "%REGLAGES%" echo Liste de courses : Gerer ^> Mon foyer ^> Partage entre appareils ^> Serveur MQTT
>> "%REGLAGES%" echo.
>> "%REGLAGES%" echo   Adresse du serveur : %ADRESSES%
>> "%REGLAGES%" echo   Port : %PORT%
>> "%REGLAGES%" echo   Connexion chiffree TLS : decochee
>> "%REGLAGES%" echo   Identifiant : %UTIL%
>> "%REGLAGES%" echo   Mot de passe : %MDP%
>> "%REGLAGES%" echo.
>> "%REGLAGES%" echo Le telephone doit etre sur le Wi-Fi de la maison, le PC allume.
type "%REGLAGES%"
echo.
echo   Ces reglages sont gardes dans "%REGLAGES%"
echo.

set "VERIF=%ICI%Verifier-serveur-MQTT.exe"
if not exist "%VERIF%" goto fin
echo Verification du serveur...
echo.
if defined AUTO (
  "%VERIF%" --hote 127.0.0.1 --port %PORT% --utilisateur %UTIL% --mot-de-passe %MDP% --sans-pause
) else (
  "%VERIF%" --hote 127.0.0.1 --port %PORT% --utilisateur %UTIL% --mot-de-passe %MDP%
)
if errorlevel 1 goto echec

:fin
echo.
echo Serveur MQTT pret.
if not defined AUTO pause
exit /b 0

:echec
echo.
echo Mise en place interrompue.
if not defined AUTO pause
exit /b 1
