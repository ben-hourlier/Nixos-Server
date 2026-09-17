{ pkgs, config, ... }:

let
  htmlPage = ../history.html;

  mediaCleanupScript = pkgs.writeShellScriptBin "media-cleanup" ''
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="${pkgs.coreutils}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.gawk}/bin:${pkgs.gnused}/bin:$PATH"

    THRESHOLD_GB=80
    MOUNT_POINT="/"
    RADARR_URL="http://localhost:7878"
    RADARR_API="RADARR_API"
    SONARR_URL="http://localhost:8989"
    SONARR_API="SONARR_API"

    JSON_FILE="/var/www/homepage/cleaner.json"

    get_free_space_gb() {
        df -BG "$MOUNT_POINT" | awk 'NR==2 {print $4}' | tr -d 'G'
    }

    get_free_space_mb() {
        df -BM "$MOUNT_POINT" | awk 'NR==2 {print $4}' | tr -d 'M'
    }

    update_json() {
        local deleted_title="$1"
        local current_free
        current_free=$(get_free_space_gb)
        local space_before=$(( current_free - THRESHOLD_GB ))
        local current_time
        current_time=$(date +"%Y-%m-%d %H:%M")

        if [ ! -f "$JSON_FILE" ]; then
            mkdir -p "$(dirname "$JSON_FILE")"
            echo '{"last_deleted_date": "Aucun", "space_before_trigger_gb": 0, "deleted_media": []}' > "$JSON_FILE"
            chown caddy:caddy "$JSON_FILE" || true
        fi

        if [ -n "$deleted_title" ]; then
            jq --arg name "$deleted_title" \
               --arg date "$current_time" \
               --argjson space "$space_before" \
               '.last_deleted_date = $date | .space_before_trigger_gb = $space | .deleted_media = [{name: $name, deleted_at: $date}] + .deleted_media' \
               "$JSON_FILE" > "$JSON_FILE.tmp" && mv "$JSON_FILE.tmp" "$JSON_FILE"
        else
            jq --argjson space "$space_before" '.space_before_trigger_gb = $space' "$JSON_FILE" > "$JSON_FILE.tmp" && mv "$JSON_FILE.tmp" "$JSON_FILE"
        fi
    }

    update_json ""

    current_space_gb=$(get_free_space_gb)
    echo "Espace libre actuel : ''${current_space_gb} Go (Seuil cible : ''${THRESHOLD_GB} Go)"

    while [ "$current_space_gb" -lt "$THRESHOLD_GB" ]; do
        # 1. Sélection du plus vieux film ayant un fichier présent sur le disque
        OLDEST_MOVIE=$(curl -s -f -L -H "X-Api-Key: $RADARR_API" "$RADARR_URL/api/v3/movie" \
            | jq -r '[.[] | select(.hasFile == true and (.sizeOnDisk // 0) > 0)] | sort_by(.added) | .[0] // empty')

        # 2. Sélection de la plus vieille série ayant des fichiers sur le disque
        OLDEST_SERIES=$(curl -s -f -L -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/series" \
            | jq -r '[.[] | select((.statistics.sizeOnDisk // 0) > 0)] | sort_by(.added) | .[0] // empty')

        if [ -z "$OLDEST_MOVIE" ] && [ -z "$OLDEST_SERIES" ]; then
            echo "Aucun média avec fichier physique trouvé à supprimer." >&2
            break
        fi

        MOVIE_DATE=$(echo "$OLDEST_MOVIE" | jq -r '.added // "9999"')
        SERIES_DATE=$(echo "$OLDEST_SERIES" | jq -r '.added // "9999"')

        initial_space_mb=$(get_free_space_mb)

        if [[ "$MOVIE_DATE" < "$SERIES_DATE" ]]; then
            MOVIE_ID=$(echo "$OLDEST_MOVIE" | jq -r '.id')
            MOVIE_TITLE=$(echo "$OLDEST_MOVIE" | jq -r '.title')
            echo "Suppression du film : $MOVIE_TITLE"
            curl -X DELETE -s -f -L -H "X-Api-Key: $RADARR_API" "$RADARR_URL/api/v3/movie/$MOVIE_ID?deleteFiles=true"
            update_json "$MOVIE_TITLE (Film)"
        else
            SERIES_ID=$(echo "$OLDEST_SERIES" | jq -r '.id')
            SERIES_TITLE=$(echo "$OLDEST_SERIES" | jq -r '.title')
            echo "Suppression de la série : $SERIES_TITLE"
            curl -X DELETE -s -f -L -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/series/$SERIES_ID?deleteFiles=true"
            update_json "$SERIES_TITLE (Série)"
        fi

        # 3. Vérification du gain d'espace effectif (mesure fine en Mo)
        wait_seconds=0
        new_space_mb=$(get_free_space_mb)
        while [ "$new_space_mb" -le "$initial_space_mb" ] && [ "$wait_seconds" -lt 15 ]; do
            sleep 1
            new_space_mb=$(get_free_space_mb)
            wait_seconds=$((wait_seconds + 1))
        done

        # Coupe-circuit : échec immédiat si aucun octet n'est libéré après suppression
        if [ "$new_space_mb" -le "$initial_space_mb" ]; then
            echo "Erreur critique : aucun espace disque libéré après suppression. Arrêt immédiat." >&2
            exit 1
        fi

        current_space_gb=$(get_free_space_gb)
        echo "Nouvel espace libre : ''${current_space_gb} Go"
    done

    echo "Objectif de ''${THRESHOLD_GB} Go atteint. Fin du nettoyage."
  '';
in
{
  environment.systemPackages = [ mediaCleanupScript ];

  systemd.tmpfiles.rules = [
    "d /var/www/homepage 0755 caddy caddy -"
    "L+ /var/www/homepage/history.html - - - - ${htmlPage}"
  ];

  systemd.services.media-cleanup = {
    description = "Service de nettoyage des vieux médias Arr";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${mediaCleanupScript}/bin/media-cleanup";
      User = "root";
    };
  };

  systemd.timers.media-cleanup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
  };
}