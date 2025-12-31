#!/bin/bash
# browse.sh
# Mode browse : exploration interactive d'une archive .arch
# Script conforme aux notions vues en cours (shell, parsing, boucle, case)

# Vérification des paramètres
if [ "$1" != "-browse" ]; then
	echo "Usage: browse.sh -browse local 0 <archive>"
	exit 1
fi

ARCHIVE="$4"

if [ ! -f "$ARCHIVE" ]; then
	echo "Erreur : archive introuvable"
	exit 1
fi

# Lecture de la première ligne : début et fin du body
HEADER=$(head -1 "$ARCHIVE")
DEBUT=$(echo "$HEADER" | cut -d':' -f1)
FIN=$(echo "$HEADER" | cut -d':' -f2)

# Extraction du body dans un fichier temporaire
TMP_BODY="/tmp/vsh_body_$$"
sed -n "${DEBUT},${FIN}p" "$ARCHIVE" > "$TMP_BODY"

# Répertoire courant (logique, pas réel)
CURRENT_DIR="."

# Fonction ls
ls_cmd() {
	grep "^$CURRENT_DIR/" "$TMP_BODY" | sed "s|^$CURRENT_DIR/||" | cut -d'/' -f1 | sort -u
}

# Fonction cat
cat_cmd() {
	local file="$1"
	grep "^$CURRENT_DIR/$file:" "$TMP_BODY" | cut -d':' -f2-
}

# Fonction cd
cd_cmd() {
	local dir="$1"
	if grep -q "^$CURRENT_DIR/$dir/" "$TMP_BODY"; then
		CURRENT_DIR="$CURRENT_DIR/$dir"
	else
		echo "vsh: cd: $dir: Aucun dossier de ce type"
	fi
}

# Boucle interactive
while true; do
	echo -n "vsh:$CURRENT_DIR> "
	read -r cmd arg

	case "$cmd" in
		ls)
			ls_cmd
			;;
		cat)
			if [ -z "$arg" ]; then
				echo "vsh: cat: argument manquant"
			else
				cat_cmd "$arg"
			fi
			;;
		cd)
			if [ -z "$arg" ]; then
				CURRENT_DIR="."
			else
				cd_cmd "$arg"
			fi
			;;
		exit)
			rm -f "$TMP_BODY"
			exit 0
			;;
		*)
			echo "Commande inconnue"
			;;
	esac
done

