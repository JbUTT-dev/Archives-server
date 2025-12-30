#!/bin/bash

# extract.sh - Extrait une archive VSH dans le répertoire courant

if [ $# -ne 1 ]; then
    echo "Usage: $0 <archive_file>" >&2
    exit 1
fi

ARCHIVE_FILE="$1"

if [ ! -f "$ARCHIVE_FILE" ]; then
    echo "Erreur: Fichier '$ARCHIVE_FILE' introuvable" >&2
    exit 1
fi

# Lire la première ligne pour obtenir les positions du header et du body
first_line=$(head -1 "$ARCHIVE_FILE")
if [[ ! "$first_line" =~ ^[0-9]+:[0-9]+$ ]]; then
    echo "Erreur: Format d'archive invalide" >&2
    exit 1
fi

header_start=$(echo "$first_line" | cut -d':' -f1)
body_start=$(echo "$first_line" | cut -d':' -f2)

echo "Lecture de l'archive..."
echo "  Header: ligne $header_start"
echo "  Body: ligne $body_start"

# Fonction pour convertir les droits rwx en octal
rights_to_octal() {
    local rights="$1"
    local octal=0
    
    # Supprimer le premier caractère (d ou -)
    rights="${rights:1}"
    
    # User (rwx)
    local user=0
    [[ "${rights:0:1}" == "r" ]] && user=$((user + 4))
    [[ "${rights:1:1}" == "w" ]] && user=$((user + 2))
    [[ "${rights:2:1}" == "x" ]] && user=$((user + 1))
    
    # Group (rwx)
    local group=0
    [[ "${rights:3:1}" == "r" ]] && group=$((group + 4))
    [[ "${rights:4:1}" == "w" ]] && group=$((group + 2))
    [[ "${rights:5:1}" == "x" ]] && group=$((group + 1))
    
    # Others (rwx)
    local others=0
    [[ "${rights:6:1}" == "r" ]] && others=$((others + 4))
    [[ "${rights:7:1}" == "w" ]] && others=$((others + 2))
    [[ "${rights:8:1}" == "x" ]] && others=$((others + 1))
    
    echo "$user$group$others"
}

# Extraire le header (entre header_start et body_start - 1)
header_end=$((body_start - 1))
total_lines=$(wc -l < "$ARCHIVE_FILE")

# Vérifier que les lignes sont valides
if [ $header_start -lt 1 ] || [ $body_start -lt 1 ] || [ $header_start -ge $body_start ]; then
    echo "Erreur: Numéros de ligne invalides (header: $header_start, body: $body_start)" >&2
    exit 1
fi

# Traiter le header pour créer les répertoires et fichiers
echo ""
echo "Extraction en cours..."

current_dir=""
created_dirs=()
created_files=()

# Lire le header ligne par ligne
sed -n "${header_start},${header_end}p" "$ARCHIVE_FILE" | while IFS= read -r line; do
    # Si c'est une ligne "directory"
    if [[ "$line" =~ ^directory\ (.+)$ ]]; then
        dir_path="${BASH_REMATCH[1]}"
        
        # Enlever le préfixe jusqu'à Test\ et le backslash final
        # Exemple: "Exemple\Test\" -> ""
        # Exemple: "Exemple\Test\A" -> "A"
        if [[ "$dir_path" =~ Test\\(.*)$ ]]; then
            dir_path="${BASH_REMATCH[1]}"
        fi
        
        # Enlever le backslash final s'il existe
        dir_path="${dir_path%\\}"
        
        # Convertir les backslashes en slashes
        dir_path="${dir_path//\\//}"
        
        current_dir="$dir_path"
        
        # Créer le répertoire s'il n'est pas vide (racine)
        if [ -n "$current_dir" ]; then
            mkdir -p "$current_dir"
            echo "  Créé: $current_dir/"
            created_dirs+=("$current_dir")
        fi
        
    # Si c'est une ligne de séparateur
    elif [[ "$line" == "@" ]]; then
        current_dir=""
        
    # Si c'est une ligne de fichier/répertoire
    elif [[ "$line" =~ ^([^\ ]+)\ ([d\-][rwx\-]{9})\ ([0-9]+)(\ ([0-9]+)\ ([0-9]+))?$ ]]; then
        name="${BASH_REMATCH[1]}"
        rights="${BASH_REMATCH[2]}"
        size="${BASH_REMATCH[3]}"
        body_line="${BASH_REMATCH[5]}"
        body_lines="${BASH_REMATCH[6]}"
        
        # Construire le chemin complet
        if [ -n "$current_dir" ]; then
            full_path="$current_dir/$name"
        else
            full_path="$name"
        fi
        
        # Si c'est un répertoire
        if [[ "${rights:0:1}" == "d" ]]; then
            mkdir -p "$full_path"
            octal=$(rights_to_octal "$rights")
            chmod "$octal" "$full_path" 2>/dev/null
            echo "  Créé: $full_path/ [$rights]"
            created_dirs+=("$full_path")
        else
            # C'est un fichier
            if [ -z "$body_line" ] || [ "$body_lines" == "0" ]; then
                # Fichier vide
                touch "$full_path"
                echo "  Créé: $full_path (vide)"
            else
                # Fichier avec contenu
                # Extraire le contenu depuis le body
                content_start=$((body_start + body_line - 1))
                content_end=$((content_start + body_lines - 1))
                
                sed -n "${content_start},${content_end}p" "$ARCHIVE_FILE" > "$full_path"
                echo "  Créé: $full_path ($body_lines lignes)"
            fi
            
            # Appliquer les droits
            octal=$(rights_to_octal "$rights")
            chmod "$octal" "$full_path" 2>/dev/null
            created_files+=("$full_path")
        fi
    fi
done

# Compter les éléments créés
num_dirs=$(find . -mindepth 1 -type d 2>/dev/null | wc -l)
num_files=$(find . -mindepth 1 -type f 2>/dev/null | wc -l)

echo ""
echo "Statistiques:"
echo "  Répertoires créés: $num_dirs"
echo "  Fichiers créés: $num_files"

exit 0
