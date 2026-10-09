import 'package:flutter/material.dart';

import '../composants/composants.dart';
import '../donnees/modele.dart';
import '../navigation.dart';
import '../theme.dart';

/// Écran 10 — Saisie d'une promotion.
class EcranPromotion extends StatefulWidget {
  const EcranPromotion({super.key, required this.produitId, this.magasinId});
  final String produitId;
  final String? magasinId;

  @override
  State<EcranPromotion> createState() => _EcranPromotionState();
}

class _EcranPromotionState extends State<EcranPromotion> {
  final etat = Etat.instance;
  late String produitId;
  late String magasinId;
  TypePromo type = TypePromo.lot;
  String marqueId = '';
  String packagingId = '';
  late DateTime debut;
  late DateTime fin;

  // Conditions
  final quantiteAchetee = TextEditingController(text: '3');
  String offert = 'article'; // 'article' ou 'remise'
  final remiseDernier = TextEditingController(text: '50');
  final quantiteMinimale = TextEditingController(text: '3');
  final prixGlobal = TextEditingController();
  int enPourcentage = 0; // 0 : pourcentage, 1 : montant
  final valeur = TextEditingController();
  final gain = TextEditingController();
  final libelle = TextEditingController();

  @override
  void initState() {
    super.initState();
    produitId = widget.produitId;
    magasinId = widget.magasinId ?? etat.magasins.first.id;
    debut = dateMaquette;
    fin = dateMaquette.add(const Duration(days: 14));
  }

  @override
  void dispose() {
    for (final c in [quantiteAchetee, remiseDernier, quantiteMinimale, prixGlobal, valeur, gain, libelle]) {
      c.dispose();
    }
    super.dispose();
  }

  int _entier(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  double _decimal(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  /// Libellé proposé quand le libellé libre est vide.
  String _libelleAuto() {
    switch (type) {
      case TypePromo.lot:
        final q = _entier(quantiteAchetee);
        return offert == 'article' ? '$q achetés = 1 offert' : '${q}e à −${_entier(remiseDernier)} %';
      case TypePromo.prixGlobal:
        return '${_entier(quantiteMinimale)} pour ${euros(_decimal(prixGlobal))}';
      case TypePromo.remise:
        return enPourcentage == 0 ? '−${_entier(valeur)} %' : '−${euros(_decimal(valeur))}';
      case TypePromo.packagingSpecial:
        return gain.text.trim().isEmpty ? 'Packaging spécial' : gain.text.trim();
      case TypePromo.fidelite:
        return enPourcentage == 0
            ? '${_entier(valeur)} % sur la carte'
            : '${euros(_decimal(valeur))} sur la carte';
      case TypePromo.autre:
        return 'Promotion';
    }
  }

  Map<String, dynamic> _parametres() {
    switch (type) {
      case TypePromo.lot:
        return offert == 'article'
            ? {'quantiteAchetee': _entier(quantiteAchetee), 'quantiteOfferte': 1}
            : {'quantiteAchetee': _entier(quantiteAchetee), 'remiseDernier': _entier(remiseDernier)};
      case TypePromo.prixGlobal:
        return {'quantiteMinimale': _entier(quantiteMinimale), 'prixGlobal': _decimal(prixGlobal)};
      case TypePromo.remise:
      case TypePromo.fidelite:
        return enPourcentage == 0 ? {'pourcentage': _entier(valeur)} : {'montant': _decimal(valeur)};
      case TypePromo.packagingSpecial:
        return {'gain': gain.text.trim()};
      case TypePromo.autre:
        return {};
    }
  }

  void _enregistrer() {
    if (type == TypePromo.packagingSpecial && packagingId.isEmpty) {
      Nav.message(context, 'Indiquez le packaging concerné');
      return;
    }
    if (type == TypePromo.autre && libelle.text.trim().isEmpty) {
      Nav.message(context, 'Indiquez le libellé de la promotion');
      return;
    }
    etat.ajouterPromotion(Promotion(
      id: etat.nouvelId('pr'),
      magasinId: magasinId,
      produitId: produitId,
      packagingId: packagingId.isEmpty ? null : packagingId,
      marqueId: marqueId.isEmpty ? null : marqueId,
      type: type,
      parametres: _parametres(),
      libelle: libelle.text.trim().isEmpty ? _libelleAuto() : libelle.text.trim(),
      debut: debut,
      fin: fin,
    ));
    Nav.message(context, 'Promotion enregistrée');
    Navigator.of(context).maybePop();
  }

  Future<void> _choisirDate(bool estDebut) async {
    final d = await showDatePicker(
      context: context,
      initialDate: estDebut ? debut : fin,
      firstDate: DateTime(2026),
      lastDate: DateTime(2028),
    );
    if (d == null) return;
    setState(() {
      if (estDebut) {
        debut = d;
        if (fin.isBefore(debut)) fin = debut;
      } else {
        fin = d.isBefore(debut) ? debut : d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = etat.produit(produitId);
    final marques = {'': 'Toutes', for (final id in p?.marqueIds ?? <String>[]) id: etat.marque(id)?.nom ?? ''};
    final packagings = {
      '': type == TypePromo.packagingSpecial ? 'À choisir' : 'Tous',
      for (final id in p?.packagingIds ?? <String>[]) id: etat.packaging(id)?.libelle ?? '',
    };
    return PageBase(
      entete: const EnTeteGestion(titre: 'Nouvelle promotion'),
      corps: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 12),
          _deuxColonnes(
            _champ(
              'Produit',
              ChoixDeroulant<String>(
                valeur: produitId,
                choix: {for (final x in etat.produits) x.id: x.nom},
                onChange: (v) => setState(() {
                  produitId = v;
                  marqueId = '';
                  packagingId = '';
                }),
              ),
            ),
            _champ(
              'Magasin',
              ChoixDeroulant<String>(
                valeur: magasinId,
                choix: {for (final m in etat.magasins) m.id: m.nom},
                onChange: (v) => setState(() => magasinId = v),
              ),
            ),
          ),
          const TitreSection('Type de promotion', cote: 0),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.45,
            children: [for (final t in TypePromo.values) _tuileType(t)],
          ),
          TitreSection('Conditions (${type.nom.toLowerCase()})', cote: 0),
          ..._conditions(packagings),
          const SizedBox(height: 12),
          _deuxColonnes(
            _champ(
              'Marque (facultatif)',
              ChoixDeroulant<String>(valeur: marqueId, choix: marques, onChange: (v) => setState(() => marqueId = v)),
            ),
            type == TypePromo.packagingSpecial
                ? const SizedBox.shrink()
                : _champ(
                    'Packaging (facultatif)',
                    ChoixDeroulant<String>(
                        valeur: packagingId, choix: packagings, onChange: (v) => setState(() => packagingId = v)),
                  ),
          ),
          const TitreSection('Période', cote: 0),
          _deuxColonnes(
            _champ('Du', _date(debut, () => _choisirDate(true))),
            _champ('Au', _date(fin, () => _choisirDate(false))),
          ),
          const SizedBox(height: 12),
          _champ(
            'Libellé libre',
            TextField(
              controller: libelle,
              style: Charte.texte(16),
              decoration: InputDecoration(hintText: 'Ex. : ${_libelleAuto()}'),
            ),
          ),
          const TitreSection("Photo de l'étiquette", cote: 0),
          InkWell(
            onTap: () => Nav.nonDisponible(context),
            child: const ImageAbsente(texte: "Photographier l'étiquette", hauteur: 80),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bas: [
        BarreAction(boutons: [Bouton(texte: 'Enregistrer la promotion', plein: true, onTap: _enregistrer)]),
        const BarreNavigation(index: 2),
      ],
    );
  }

  List<Widget> _conditions(Map<String, String> packagings) {
    switch (type) {
      case TypePromo.lot:
        return [
          _deuxColonnes(
            _champ('Quantité achetée', _nombre(quantiteAchetee)),
            _champ(
              'Offert',
              ChoixDeroulant<String>(
                valeur: offert,
                choix: const {'article': '1 article', 'remise': 'Remise sur le dernier'},
                onChange: (v) => setState(() => offert = v),
              ),
            ),
          ),
          if (offert == 'remise') ...[
            const SizedBox(height: 12),
            _champ('Remise sur le dernier (%)', _nombre(remiseDernier)),
          ],
        ];
      case TypePromo.prixGlobal:
        return [
          _deuxColonnes(
            _champ('Quantité minimale', _nombre(quantiteMinimale)),
            _champ('Prix global (€)', _nombre(prixGlobal, decimal: true)),
          ),
        ];
      case TypePromo.remise:
      case TypePromo.fidelite:
        return [
          Bascule(
            options: const ['Pourcentage', 'Montant'],
            index: enPourcentage,
            onChange: (i) => setState(() => enPourcentage = i),
          ),
          const SizedBox(height: 12),
          _champ(
            enPourcentage == 0
                ? (type == TypePromo.fidelite ? 'Pourcentage crédité (%)' : 'Pourcentage (%)')
                : (type == TypePromo.fidelite ? 'Montant crédité (€)' : 'Montant (€)'),
            _nombre(valeur, decimal: enPourcentage == 1),
          ),
        ];
      case TypePromo.packagingSpecial:
        return [
          _deuxColonnes(
            _champ(
              'Packaging concerné',
              ChoixDeroulant<String>(
                  valeur: packagingId, choix: packagings, onChange: (v) => setState(() => packagingId = v)),
            ),
            _champ(
              'Gain',
              TextField(
                controller: gain,
                style: Charte.texte(16),
                decoration: const InputDecoration(hintText: '+20 % gratuit'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ];
      case TypePromo.autre:
        return [
          Text('Décrivez la promotion dans le libellé libre ci-dessous.',
              style: Charte.texte(14, couleur: Charte.texteSecondaire)),
        ];
    }
  }

  Widget _tuileType(TypePromo t) {
    final choisi = t == type;
    return Material(
      color: choisi ? Charte.encre : Charte.fond,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Charte.encre, width: Charte.traitCadre),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          type = t;
          enPourcentage = 0;
        }),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconePromo(type: t, inverse: choisi),
            const SizedBox(height: 6),
            Text(t.nom, style: Charte.texte(14, gras: choisi, couleur: choisi ? Charte.fond : Charte.encre)),
          ],
        ),
      ),
    );
  }

  Widget _champ(String etiquette, Widget champ) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiquette, style: Charte.texte(13, couleur: Charte.texteSecondaire)),
          const SizedBox(height: 4),
          champ,
        ],
      );

  Widget _deuxColonnes(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
      );

  Widget _nombre(TextEditingController c, {bool decimal = false}) => TextField(
        controller: c,
        style: Charte.texte(16),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        onChanged: (_) => setState(() {}),
      );

  Widget _date(DateTime d, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Charte.encre, width: Charte.traitCadre),
          ),
          child: Row(
            children: [
              Expanded(child: Text(jjmmaaaa(d), style: Charte.texte(16))),
              const Icon(Icons.calendar_today_outlined, size: 18, color: Charte.encre),
            ],
          ),
        ),
      );
}
