{ pkgs, config, ... }:

let
  mediaCleanupScript = pkgs.writeShellScriptBin "media-cleanup" ''
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="${pkgs.coreutils}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.gawk}/bin:${pkgs.gnused}/bin:$PATH"

    THRESHOLD_GB=80
    MOUNT_POINT="/"
    RADARR_URL="http://localhost:7878"
    RADARR_API="''${RADARR_API:?RADARR_API variable must be set}"
    SONARR_URL="http://localhost:8989"
    SONARR_API="''${SONARR_API:?SONARR_API variable must be set}"

    LOG_FILE="/var/www/homepage/cleaner.log"
    STATUS_JSON="/var/www/homepage/cleaner.json"

    mkdir -p /var/www/homepage

    # Initialize log file if missing
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 644 "$LOG_FILE"
    fi

    get_free_space_gb() {
        df -BG "$MOUNT_POINT" | awk 'NR==2 {print $4}' | tr -d 'G'
    }

    get_free_space_mb() {
        df -BM "$MOUNT_POINT" | awk 'NR==2 {print $4}' | tr -d 'M'
    }

    update_status_json() {
        local space_gb="$1"
        local margin=$(( space_gb - THRESHOLD_GB ))
        
        jq -n --argjson margin "$margin" \
           '{space_before_trigger_gb: $margin}' > "''${STATUS_JSON}.tmp"
        mv "''${STATUS_JSON}.tmp" "$STATUS_JSON"
        chmod 644 "$STATUS_JSON"
    }

    log_deletion() {
        local item="$1"
        local now
        now=$(date +"%Y-%m-%d %H:%M")
        echo "[$now] Removed: $item" >> "$LOG_FILE"
        
        # Keep only the last 50 entries
        tail -n 50 "$LOG_FILE" > "''${LOG_FILE}.tmp" && mv "''${LOG_FILE}.tmp" "$LOG_FILE"
        chmod 644 "$LOG_FILE"
    }

    current_space_gb=$(get_free_space_gb)
    echo "Current free space: ''${current_space_gb} GB (Target threshold: ''${THRESHOLD_GB} GB)"

    # Update dashboard widget immediately
    update_status_json "$current_space_gb"

    while [ "$current_space_gb" -lt "$THRESHOLD_GB" ]; do
        # 1. Fetch oldest movie with physical file on disk
        OLDEST_MOVIE=$(curl -s -f -L -H "X-Api-Key: $RADARR_API" "$RADARR_URL/api/v3/movie" \
            | jq -r '[.[] | select(.hasFile == true and (.sizeOnDisk // 0) > 0)] | sort_by(.added) | .[0] // empty')

        # 2. Fetch oldest series with physical files on disk
        OLDEST_SERIES=$(curl -s -f -L -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/series" \
            | jq -r '[.[] | select((.statistics.sizeOnDisk // 0) > 0)] | sort_by(.added) | .[0] // empty')

        if [ -z "$OLDEST_MOVIE" ] && [ -z "$OLDEST_SERIES" ]; then
            echo "No media with physical files found to delete." >&2
            break
        fi

        MOVIE_DATE=$(echo "$OLDEST_MOVIE" | jq -r '.added // "9999"')
        SERIES_DATE=$(echo "$OLDEST_SERIES" | jq -r '.added // "9999"')

        initial_space_mb=$(get_free_space_mb)

        if [[ "$MOVIE_DATE" < "$SERIES_DATE" ]]; then
            MOVIE_ID=$(echo "$OLDEST_MOVIE" | jq -r '.id')
            MOVIE_TITLE=$(echo "$OLDEST_MOVIE" | jq -r '.title')
            echo "Deleting movie: $MOVIE_TITLE"
            curl -X DELETE -s -f -L -H "X-Api-Key: $RADARR_API" "$RADARR_URL/api/v3/movie/$MOVIE_ID?deleteFiles=true"
            log_deletion "$MOVIE_TITLE (Movie)"
        else
            SERIES_ID=$(echo "$OLDEST_SERIES" | jq -r '.id')
            SERIES_TITLE=$(echo "$OLDEST_SERIES" | jq -r '.title')
            echo "Deleting series: $SERIES_TITLE"
            curl -X DELETE -s -f -L -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/series/$SERIES_ID?deleteFiles=true"
            log_deletion "$SERIES_TITLE (Series)"
        fi

        # 3. Wait and verify reclaimed space
        wait_seconds=0
        new_space_mb=$(get_free_space_mb)
        while [ "$new_space_mb" -le "$initial_space_mb" ] && [ "$wait_seconds" -lt 15 ]; do
            sleep 1
            new_space_mb=$(get_free_space_mb)
            wait_seconds=$((wait_seconds + 1))
        done

        # Circuit breaker: fail if no space was freed
        if [ "$new_space_mb" -le "$initial_space_mb" ]; then
            echo "Critical error: no disk space freed after deletion. Aborting." >&2
            exit 1
        fi

        current_space_gb=$(get_free_space_gb)
        echo "Updated free space: ''${current_space_gb} GB"
        update_status_json "$current_space_gb"
    done

    echo "Target of ''${THRESHOLD_GB} GB reached. Cleanup completed."
  '';
in
{
  environment.systemPackages = [ mediaCleanupScript ];

  systemd.tmpfiles.rules = [
    "d /var/www/homepage 0755 caddy caddy -"
  ];

  systemd.services.media-cleanup = {
    description = "Arr media automatic cleanup service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${mediaCleanupScript}/bin/media-cleanup";
      EnvironmentFile = config.sops.secrets.media_cleanup.path;
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