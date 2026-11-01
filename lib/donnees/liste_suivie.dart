import 'dart:collection';

// Recherche rapide (01/11/2026) : avec 17 000 emplacements, retrouver le secteur d'un article en parcourant
// toute la liste à chaque fois faisait des dizaines de millions de comparaisons par affichage d'une liste
// (3 à 4 secondes par changement d'onglet sur le téléphone). Ces listes notent chaque modification ; les
// index se reconstruisent seulement quand elles ont changé.

/// Liste qui compte ses modifications ([version]).
class ListeSuivie<T> extends ListBase<T> {
  ListeSuivie(this._l);
  final List<T> _l;
  int version = 0;

  @override
  int get length => _l.length;

  @override
  set length(int n) {
    _l.length = n;
    version++;
  }

  @override
  T operator [](int i) => _l[i];

  @override
  void operator []=(int i, T v) {
    _l[i] = v;
    version++;
  }

  @override
  void add(T element) {
    _l.add(element);
    version++;
  }

  @override
  void addAll(Iterable<T> iterable) {
    _l.addAll(iterable);
    version++;
  }

  @override
  bool remove(Object? element) {
    version++;
    return _l.remove(element);
  }

  @override
  void removeWhere(bool Function(T) test) {
    _l.removeWhere(test);
    version++;
  }

  @override
  void retainWhere(bool Function(T) test) {
    _l.retainWhere(test);
    version++;
  }

  @override
  void insert(int index, T element) {
    _l.insert(index, element);
    version++;
  }

  @override
  T removeAt(int index) {
    version++;
    return _l.removeAt(index);
  }

  @override
  void clear() {
    _l.clear();
    version++;
  }

  @override
  void sort([int Function(T, T)? compare]) {
    _l.sort(compare);
    version++;
  }
}

/// Index d'une [ListeSuivie] par clé (le premier élément de chaque clé, comme une recherche du début).
class Index<T> {
  Index(this.cle);
  final String Function(T) cle;
  ListeSuivie<T>? _liste;
  int _version = -1;
  final Map<String, T> _map = {};

  T? trouver(ListeSuivie<T> liste, String k) {
    if (!identical(liste, _liste) || liste.version != _version) {
      _map.clear();
      for (final e in liste) {
        _map.putIfAbsent(cle(e), () => e);
      }
      _liste = liste;
      _version = liste.version;
    }
    return _map[k];
  }
}
