// Tri du Takeout Google Keep : garde les notes dont un libellé contient « Recette »
// (avec leur page HTML et leurs pièces jointes) ; tout le reste part dans un sous-dossier, rien n'est effacé.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type note struct {
	Title  string `json:"title"`
	Labels []struct {
		Name string `json:"name"`
	} `json:"labels"`
	Attachments []struct {
		FilePath string `json:"filePath"`
	} `json:"attachments"`
}

const ecartes = "Autres notes (a supprimer)"

func attendre() {
	fmt.Print("\nAppuyez sur Entrée pour fermer.")
	bufio.NewReader(os.Stdin).ReadString('\n')
}

func main() {
	defer attendre()
	exe, err := os.Executable()
	if err != nil {
		fmt.Println("Erreur :", err)
		return
	}
	dir := filepath.Dir(exe)
	moi := filepath.Base(exe)
	fmt.Println("Tri des notes Keep dans :", dir)
	entrees, err := os.ReadDir(dir)
	if err != nil {
		fmt.Println("Erreur :", err)
		return
	}
	garder := map[string]bool{moi: true}
	nbNotes, nbRecettes := 0, 0
	var titres []string
	for _, e := range entrees {
		if e.IsDir() || !strings.EqualFold(filepath.Ext(e.Name()), ".json") {
			continue
		}
		b, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			continue
		}
		var n note
		if json.Unmarshal(b, &n) != nil {
			continue
		}
		nbNotes++
		ok := false
		for _, l := range n.Labels {
			if strings.Contains(strings.ToLower(l.Name), "recette") {
				ok = true
			}
		}
		if !ok {
			continue
		}
		nbRecettes++
		titres = append(titres, n.Title)
		base := strings.TrimSuffix(e.Name(), filepath.Ext(e.Name()))
		garder[e.Name()] = true
		garder[base+".html"] = true
		for _, a := range n.Attachments {
			garder[filepath.Base(a.FilePath)] = true
		}
	}
	var aDeplacer []string
	for _, e := range entrees {
		if !e.IsDir() && !garder[e.Name()] {
			aDeplacer = append(aDeplacer, e.Name())
		}
	}
	fmt.Printf("\n%d notes lues, %d avec le libellé « Recettes ».\n", nbNotes, nbRecettes)
	if nbRecettes == 0 {
		fmt.Println("Aucune recette trouvée : rien n'est déplacé. Placez ce programme dans le dossier Takeout\\Keep.")
		return
	}
	for i, t := range titres {
		if i == 15 {
			fmt.Printf("  … et %d autres\n", len(titres)-15)
			break
		}
		fmt.Println("  •", t)
	}
	fmt.Printf("\n%d fichiers qui ne sont pas des recettes seront DÉPLACÉS dans le sous-dossier « %s ».\n", len(aDeplacer), ecartes)
	fmt.Print("Rien n'est effacé. Tapez O puis Entrée pour continuer : ")
	r, _ := bufio.NewReader(os.Stdin).ReadString('\n')
	if !strings.EqualFold(strings.TrimSpace(r), "o") {
		fmt.Println("Abandon : rien n'a été modifié.")
		return
	}
	cible := filepath.Join(dir, ecartes)
	if err := os.MkdirAll(cible, 0o755); err != nil {
		fmt.Println("Erreur :", err)
		return
	}
	nb := 0
	for _, f := range aDeplacer {
		if err := os.Rename(filepath.Join(dir, f), filepath.Join(cible, f)); err != nil {
			fmt.Println("Non déplacé :", f, err)
		} else {
			nb++
		}
	}
	fmt.Printf("\nTerminé : %d fichiers déplacés. Il ne reste que les recettes dans ce dossier.\n", nb)
	fmt.Println("Vérifiez, puis supprimez le sous-dossier « " + ecartes + " » si tout va bien.")
}
