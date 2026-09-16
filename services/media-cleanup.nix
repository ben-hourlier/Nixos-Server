{ pkgs, config, ... }:

let
  htmlPage = ../history.html;

  # On déclare proprement le script ici pour pouvoir interpoler son chemin exact
  mediaCleanupScript = pkgs.writeShellScriptBin "media-cleanup" ''
    #!/usr/bin/env bash
    export PATH="${pkgs.coreutils}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.gawk}/bin:${pkgs.gnused}/bin:$PATH"

    THRESHOLD=80
    MOUNT_POINT="/"
    RADARR_URL="http://localhost:7878"
    RADARR_API="RADARR_API"
    SONARR_URL="http://localhost:8989"
    SONARR_API="SONARR_API"

    JSON_FILE="/var/www/homepage/cleaner.json"

    get_free_space() {
        df -BG "$MOUNT_POINT" | awk 'NR==2 {print $4}' | sed 's/G//'
    }

    update_json() {
        local deleted_title="$1"
        local current_free
        current_free=$(get_free_space)
        local space_before=$(( current_free - THRESHOLD ))
        local current_time
        current_time=$(date +"%Y-%m-%d %H:%M")

        if [ ! -f "$JSON_FILE" ]; then
            mkdir -p "$(dirname "$JSON_FILE")"
            echo '{"last_deleted_date": "Aucun", "space_before_trigger_gb": 0, "deleted_media": []}' > "$JSON_FILE"
            chown caddy:caddy "$JSON_FILE"
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

    initial_space=$(get_free_space)

    echo $initial_space

    while [ "$initial_space" -lt "$THRESHOLD" ]; do
        OLDEST_MOVIE=$(curl -s -L -H "X-Api-Key: $RADARR_API" "$RADARR_URL/api/v3/movie" | jq -r 'sort_by(.added) | .[0] | {id: .id, title: .title, added: .added}')
        MOVIE_ID=$(echo "$OLDEST_MOVIE" | jq -r '.id')
        MOVIE_DATE=$(echo "$OLDEST_MOVIE" | jq -r '.added')
        MOVIE_TITLE=$(echo "$OLDEST_MOVIE" | jq -r '.title')

        OLDEST_SERIES=$(curl -s -L -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/series" | jq -r 'sort_by(.added) | .[0] | {id: .id, title: .title, added: .added}')
        SERIES_ID=$(echo "$OLDEST_SERIES" | jq -r '.id')
        SERIES_DATE=$(echo "$OLDEST_SERIES" | jq -r '.added')
        SERIES_TITLE=$(echo "$OLDEST_SERIES" | jq -r '.title')

        if [[ "$MOVIE_DATE" < "$SERIES_DATE" ]]; then
            curl -X DELETE -s -L -H "X-Api-Key: $RADARR_API" "$RADARR_URL/api/v3/movie/$MOVIE_ID?deleteFiles=true"
            update_json "$MOVIE_TITLE (Film)"
        else
            curl -X DELETE -s -L -H "X-Api-Key: $SONARR_API" "$RADARR_URL/api/v3/series/$SERIES_ID?deleteFiles=true"
            update_json "$SERIES_TITLE (Série)"
        fi

        new_space=$(get_free_space)
        count=0
        count_max=10
        while [[ $new_space == $initial_space ]]; do
            sleep 1
            new_space=$(get_free_space)
            ((count+=1))
            if [[ $count -gt $count_max ]]; then
                echo "No space gained after deletion. Service stopped." >&2
                exit 1
            fi
        done
        initial_space=$new_space
    done
  '';
in
{
  # Ajoute le script aux paquets système disponibles
  environment.systemPackages = [ mediaCleanupScript ];

  # Règle de lien symbolique pour la page HTML statique
  systemd.tmpfiles.rules = [
    "d /var/www/homepage 0755 caddy caddy -"
    "L+ /var/www/homepage/history.html - - - - ${htmlPage}"
  ];

  systemd.services.media-cleanup = {
    description = "Service de nettoyage des vieux médias Arr";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${mediaCleanupScript}/bin/media-cleanup"; # Utilise la variable locale
      User = "root";
    };
  };

  systemd.timers.media-cleanup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}