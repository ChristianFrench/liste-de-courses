import 'dart:typed_data';

/// Session de console shell sur le serveur.
abstract class SessionShell {
  Stream<Uint8List> get sortie;
  void ecrire(Uint8List donnees);
  void redimensionner(int colonnes, int lignes);
  Future<void> get fin;
  void fermer();
}

/// Navigateur : pas d'accès SSH (la console d'administration est une application Windows).
class AccesServeur {
  static const disponible = false;
  Never _non() => throw UnsupportedError('Accès au serveur : application Windows seulement');
  Future<void> connecter(
          {required String hote,
          required String utilisateur,
          String? motDePasse,
          String? empreinte,
          required void Function(String) nouvelleEmpreinte}) async =>
      _non();
  Future<String> executer(String commande) async => _non();
  Future<SessionShell> shell(int colonnes, int lignes) async => _non();
  Future<String?> clePublique() async => null;
  Future<void> creerCle(String commentaire) async => _non();
  Future<String?> adresse(String nom) async => null;
  void fermer() {}
}
