import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'demonstration.dart';

/// Dossier de données de l'application. L'outil de l'éditeur du catalogue (Windows) range les siennes
/// dans un sous-dossier « editeur » : ses bases ne se mêlent jamais à celles d'Emplettes installée sur le même PC.
Future<Directory> dossierApplication() async {
  final d = await getApplicationSupportDirectory();
  return outilEditeur ? Directory('${d.path}${Platform.pathSeparator}editeur') : d;
}
