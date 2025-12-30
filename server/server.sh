#!/bin/bash
# server.sh - serveur VSH avec envoi des réponses au client (named pipe)

PORT=$1
ARCHIVES_DIR="./archives"

# Créer le répertoire archives s'il n'existe pas
mkdir -p "$ARCHIVES_DIR"

echo "VSH server listening on port $PORT"
echo "Archives directory: $ARCHIVES_DIR"

while true; do
	# Créer des fichiers temporaires
	TEMP_FILE=$(mktemp)
	
	# Utiliser un named pipe pour la réponse bidirectionnelle
	FIFO="/tmp/vsh_fifo_$$"
	mkfifo "$FIFO"
	
	# Lancer nc avec la FIFO pour permettre la bidirectionnalité
	nc -l -p "$PORT" < "$FIFO" | {
		# Sauvegarder la requête
		tee "$TEMP_FILE" | head -1 | {
			read -r cmd_line
			
			# Séparer la commande et l'argument avec |
			cmd=$(echo "$cmd_line" | cut -d'|' -f1)
			arg=$(echo "$cmd_line" | cut -d'|' -f2)
			
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] Commande reçue: $cmd $arg" >&2
			
			# Traiter la commande et envoyer la réponse dans la FIFO
			case "$cmd" in
				# ---------------- CREATE ----------------
				CREATE)
					# Attendre que tout le fichier soit reçu
					sleep 0.2
					
					archive_name="$arg"
					
					# Ajouter .arch si nécessaire
					if [[ ! "$archive_name" =~ \.arch$ ]]; then
						archive_name="${archive_name}.arch"
					fi
					
					archive_path="$ARCHIVES_DIR/$archive_name"
					
					# Extraire le contenu (tout sauf la première ligne et les 2 dernières)
					tail -n +2 "$TEMP_FILE" | head -n -2 > "$archive_path"
					
					if [ -s "$archive_path" ]; then
						echo "OK: Archive '$archive_name' créée avec succès"
						echo "Taille: $(du -h "$archive_path" | cut -f1)"
						echo "---"
						ls -lh "$archive_path" >&2
					else
						echo "ERROR: Archive vide ou non créée"
						rm -f "$archive_path"
					fi
					;;
					
				# ---------------- LIST ----------------
				LIST)
					# Exécuter list.sh
					if [ -f "./list.sh" ]; then
						bash ./list.sh
					else
						# Fallback si list.sh n'existe pas
						echo "=== Archives disponibles ==="
						if [ -d "$ARCHIVES_DIR" ]; then
							count=$(find "$ARCHIVES_DIR" -maxdepth 1 -name "*.arch" -type f 2>/dev/null | wc -l)
							if [ "$count" -eq 0 ]; then
								echo "Aucune archive disponible"
							else
								echo ""
								find "$ARCHIVES_DIR" -maxdepth 1 -name "*.arch" -type f 2>/dev/null | sort | while read -r archive; do
									name=$(basename "$archive")
									size=$(du -h "$archive" | cut -f1)
									printf "  %-30s  %8s\n" "$name" "$size"
								done
							fi
						else
							echo "Aucune archive disponible"
						fi
						echo ""
						echo "=== Fin de la liste ==="
					fi
					
					echo "---"
					echo "Liste envoyée au client" >&2
					;;
					
	
				# ---------------- EXTRACT ----------------
				EXTRACT)
    					archive_name="$arg"
    
    					# Ajouter .arch si nécessaire
    					if [[ ! "$archive_name" =~ \.arch$ ]]; then
       						archive_name="${archive_name}.arch"
    					fi
    
    					archive_path="$ARCHIVES_DIR/$archive_name"
    
    					if [[ -f "$archive_path" ]]; then
        					echo "Envoi de l'archive '$archive_name'..." >&2
        					cat "$archive_path"
        					echo ""
        					echo "<<<END_ARCHIVE>>>"  # Utilisez le même marqueur que dans vsh
    					else
        					echo "ERROR: Archive '$archive_name' introuvable"
   					fi
    					;;
					
				# ---------------- BROWSE ----------------
				BROWSE)
					archive_name="$arg"
					
					# Ajouter .arch si nécessaire
					if [[ ! "$archive_name" =~ \.arch$ ]]; then
						archive_name="${archive_name}.arch"
					fi
					
					archive_path="$ARCHIVES_DIR/$archive_name"
					
					if [[ -f "$archive_path" ]]; then
						echo "$archive_path"
					else
						echo "ERROR: Archive '$archive_name' introuvable"
					fi
					;;
					
				# ---------------- ERREUR ----------------
				*)
					echo "ERROR: Commande inconnue '$cmd'"
					;;
			esac
		} > "$FIFO"
	}
	
	# Nettoyer
	rm -f "$TEMP_FILE" "$FIFO"
	
	echo "---" >&2
done
