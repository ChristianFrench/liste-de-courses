/// Version de l'application, fournie à la compilation : numéro (VERSION) et commit (COMMIT), passés séparément
/// car sous Windows les parenthèses et espaces d'une seule valeur cassent la ligne de commande de flutter.bat.
const _numero = String.fromEnvironment('VERSION', defaultValue: 'essai');
const _commit = String.fromEnvironment('COMMIT');
const versionApplication = _commit == '' ? _numero : '$_numero ($_commit)';
