"""Transforme les messages d'analyse, de test ou de compilation en annotations GitHub
(visibles dans l'onglet Actions, au-dessus des journaux). Lancé automatiquement par
GitHub Actions ; rien à faire à la main.

Usage : python outils/annoter.py <journal> <titre> [analyse]
"""
import re
import sys


def echapper(texte):
    return texte.replace("%", "%25").replace("\r", "").replace("\n", "%0A")


def annoter_analyse(lignes, titre):
    motif = re.compile(r"^\s*(error|warning|info)\s+[•-]\s+(.*?)\s+[•-]\s+(\S+?):(\d+):(\d+)\s+[•-]\s+(\S+)\s*$")
    compte = {"error": 0, "warning": 0, "info": 0}
    for ligne in lignes:
        m = motif.match(ligne)
        if not m:
            continue
        niveau, message, fichier, lig, col, code = m.groups()
        compte[niveau] += 1
        genre = {"error": "error", "warning": "warning", "info": "notice"}[niveau]
        print(f"::{genre} file={fichier},line={lig},col={col},title={titre}::{echapper(message + ' (' + code + ')')}")
    print(f"{titre} : {compte['error']} erreur(s), {compte['warning']} avertissement(s), {compte['info']} remarque(s)")


def annoter_journal(lignes, titre):
    """Annote les passages d'échec d'un journal de test ou de compilation."""
    texte = "".join(lignes)
    marqueurs = ["EXCEPTION CAUGHT", "Error:", "error:", "Expected:", "FAILURE:", "Test failed", "[E]", "error C", "error G"]
    debut = None
    for i, ligne in enumerate(lignes):
        if any(m in ligne for m in marqueurs):
            debut = i
            break
    if debut is None:
        extrait = lignes[-80:]
    else:
        extrait = lignes[max(0, debut - 5):]
    texte = "".join(extrait)
    morceaux = [texte[i:i + 3500] for i in range(0, len(texte), 3500)][:9]
    for n, morceau in enumerate(morceaux, 1):
        print(f"::error title={titre} ({n}/{len(morceaux)})::{echapper(morceau)}")


def main():
    if len(sys.argv) < 3:
        sys.exit("usage : annoter.py <journal> <titre> [analyse]")
    with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
        lignes = f.readlines()
    sys.stdout.write("".join(lignes[-200:]))
    if len(sys.argv) > 3 and sys.argv[3] == "analyse":
        annoter_analyse(lignes, sys.argv[2])
    else:
        annoter_journal(lignes, sys.argv[2])


if __name__ == "__main__":
    main()
