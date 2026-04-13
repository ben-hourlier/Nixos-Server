#!/usr/bin/env bash

# --- CONFIGURATION ---
THRESHOLD=120
MOUNT_POINT="/"
RADARR_URL="http://localhost:7878"
RADARR_API="RADARR_API"
SONARR_URL="http://localhost:8989"
SONARR_API="SONARR_API"

# --- LOGIQUE DE VÉRIFICATION D'ESPACE ---
get_free_space() {
    df -BG "$MOUNT_POINT" | awk 'NR==2 {print $4}' | sed 's/G//'
}

while [ "$(get_free_space)" -lt "$THRESHOLD" ]; do
    OLDEST_MOVIE=$(curl -s -L -H "X-Api-Key: $RADARR_API" "$RADARR_URL/api/v3/movie" | \
        jq -r 'sort_by(.added) | .[0] | {id: .id, title: .title, added: .added}')
    
    MOVIE_ID=$(echo $OLDEST_MOVIE | jq -r '.id')
    MOVIE_DATE=$(echo $OLDEST_MOVIE | jq -r '.added')
    MOVIE_TITLE=$(echo $OLDEST_MOVIE | jq -r '.title')


    OLDEST_SERIES=$(curl -s -L -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/series" | \
        jq -r 'sort_by(.added) | .[0] | {id: .id, title: .title, added: .added}')
    
    SERIES_ID=$(echo $OLDEST_SERIES | jq -r '.id')
    SERIES_DATE=$(echo $OLDEST_SERIES | jq -r '.added')
    SERIES_TITLE=$(echo $OLDEST_SERIES | jq -r '.title')

    if [[ "$MOVIE_DATE" < "$SERIES_DATE" ]]; then
        curl -X DELETE -s -L -H "X-Api-Key: $RADARR_API" \
             "$RADARR_URL/api/v3/movie/$MOVIE_ID?deleteFiles=true"
    else
        curl -X DELETE -s -L -H "X-Api-Key: $SONARR_API" \
             "$SONARR_URL/api/v3/series/$SERIES_ID?deleteFiles=true"
    fi

    sleep 5
done