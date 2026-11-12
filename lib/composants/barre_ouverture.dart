import 'package:flutter/foundation.dart';

/// Avancement de la mise à jour faite à l'ouverture (texte et valeur de 0 à 1), null une fois finie.
/// Mis à jour par GuetteurMiseAJour (coquille.dart), affiché par la fenêtre de progression (FenetreOuverture, coquille.dart) ;
/// plus de barre sur la photo de l'accueil depuis le 12/11/2026.
final ouvertureEnCours = ValueNotifier<({String texte, double valeur})?>(null);
