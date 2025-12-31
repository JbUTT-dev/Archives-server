#!/bin/bash

# Script pour créer une archive au format spécifié
# Usage: ./create.sh <nom_archive> <repertoire_source>

ARCHIVE_NAME="$1"
SOURCE_DIR="$2"
ARCHIVE_DIR="./archives"

# Vérification des arguments
if [ $# -ne 2 ]; then
    echo "Erreur: Usage: $0 <nom_archive> <repertoire_source>" >&2
    exit 1
fi

# Vérifier que le répertoire source existe
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Erreur: Le répertoire source '$SOURCE_DIR' n'existe pas" >&2
    exit 1
fi

# Ajouter l'extension .arch si absente
if [[ ! "$ARCHIVE_NAME" =~ \.arch$ ]]; then
    ARCHIVE_NAME="${ARCHIVE_NAME}.arch"
fi

# Créer le répertoire d'archives
mkdir -p "$ARCHIVE_DIR"

ARCHIVE_PATH="$ARCHIVE_DIR/$ARCHIVE_NAME"
TEMP_HEADER=$(mktemp)
TEMP_BODY=$(mktemp)

# Fonction pour obtenir les permissions au format textuel
get_permissions() {
    local file="$1"
    ls -ld "$file" | cut -c1-10
}

# Fonction pour obtenir la taille en octets
get_size() {
    stat -c "%s" "$1" 2>/dev/null || stat -f "%z" "$1" 2>/dev/null || echo "0"
}

# Compteur de lignes dans le body
BODY_LINE=1

# Fonction récursive pour traiter un répertoire
process_directory() {
    local dir="$1"
    local archive_path="$2"
    
    # En-tête du répertoire
    echo "directory $archive_path" >> "$TEMP_HEADER"
    
    # Lister le contenu (fichiers et répertoires)
    find "$dir" -maxdepth 1 -mindepth 1 ! -name '.*' -printf "%f\n" 2>/dev/null | sort | while read -r item; do
        local fullpath="$dir/$item"
        
        # Ignorer si n'existe pas
        [ -e "$fullpath" ] || continue
        
        local perms=$(get_permissions "$fullpath")
        local size=$(get_size "$fullpath")
        
        if [ -d "$fullpath" ]; then
            # C'est un répertoire
            echo "$item $perms $size" >> "$TEMP_HEADER"
            
        elif [ -f "$fullpath" ]; then
            # C'est un fichier
            if [ "$size" -eq 0 ]; then
                # Fichier vide
                echo "$item $perms 0" >> "$TEMP_HEADER"
            else
                # Fichier non vide - vérifier si c'est du texte
                if file "$fullpath" | grep -q "text"; then
                    # Compter les lignes
                    local num_lines=$(wc -l < "$fullpath")
                    
                    # Ajouter 1 si pas de newline final
                    if [ -s "$fullpath" ]; then
                        local last_char=$(tail -c 1 "$fullpath" | od -An -tx1 | tr -d ' \n')
                        if [ "$last_char" != "0a" ]; then
                            num_lines=$((num_lines + 1))
                        fi
                    fi
                    
                    # Ajouter l'entrée au header
                    echo "$item $perms $size $BODY_LINE $num_lines" >> "$TEMP_HEADER"
                    
                    # Ajouter le contenu au body
                    cat "$fullpath" >> "$TEMP_BODY"
                    
                    # Mettre à jour le compteur
                    BODY_LINE=$((BODY_LINE + num_lines))
                else
                    # Fichier binaire - ignorer pour ce projet (seulement texte)
                    echo "$item $perms 0" >> "$TEMP_HEADER"
                fi
            fi
        fi
    done
    
    # Fin du répertoire
    echo "@" >> "$TEMP_HEADER"
    
    # Traiter récursivement les sous-répertoires
    find "$dir" -maxdepth 1 -mindepth 1 -type d ! -name '.*' -printf "%f\n" 2>/dev/null | sort | while read -r subdir; do
        local fullpath="$dir/$subdir"
        [ -d "$fullpath" ] || continue
        process_directory "$fullpath" "$archive_path\\$subdir"
    done
}

# Obtenir le nom du répertoire racine
if [ "$SOURCE_DIR" = "." ]; then
    ROOT_NAME=$(basename "$(pwd)")
else
    ROOT_NAME=$(basename "$(cd "$SOURCE_DIR" && pwd)")
fi

echo "Création de l'archive pour: $ROOT_NAME" >&2

# Traiter l'arborescence
process_directory "$SOURCE_DIR" "$ROOT_NAME"

# Calculer les numéros de lignes
HEADER_START=2
HEADER_LINES=$(wc -l < "$TEMP_HEADER")
BODY_START=$((HEADER_START + HEADER_LINES))

# Créer l'archive finale
{
    echo "$HEADER_START:$BODY_START"
    cat "$TEMP_HEADER"
    cat "$TEMP_BODY"
} > "$ARCHIVE_PATH"

# Nettoyer les fichiers temporaires
rm -f "$TEMP_HEADER" "$TEMP_BODY"

echo "Archive créée avec succès: $ARCHIVE_PATH" >&2
echo "Header commence à la ligne $HEADER_START" >&2
echo "Body commence à la ligne $BODY_START" >&2

exit 0
