{ config, pkgs, ... }:

let
  githubRepos = [
    "git@github.com:jarvis-ed1th/FocusOS.git"
    "git@github.com:jarvis-ed1th/Digital-Brain.git"
    "git@github.com:jarvis-ed1th/expense-report-creator.git"
    "git@github.com:jarvis-ed1th/server1-nixos.git"
  ];
in
{
  # ====================================================================
  # --- Github synchronisation ---
  # ====================================================================  

  systemd.services.github-sync = {
    description = "GitHub Repositories Sync";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [ git openssh ];

    serviceConfig = {
      Type = "oneshot";
      User = "root"; 
    };

    script = ''
      mkdir -p /mnt/disk1/backups/github
      cd /mnt/disk1/backups/github
      
      ${pkgs.lib.concatMapStringsSep "\n" (repo: ''
        repo_name=$(basename "${repo}" .git)
        if [ -d "$repo_name.git" ]; then
          cd "$repo_name.git" && git remote update && cd ..
        else
          git clone --mirror "${repo}" "$repo_name.git"
        fi
      '') githubRepos}
    '';
  };


  # ====================================================================
  # --- Backup ---
  # ====================================================================

  systemd.services.kopia-server-backup = {
    description = "Kopia Backup";
    wants = [ "github-sync.service" ];
    after = [ "github-sync.service" "mnt-disk1.mount" ];
    path = with pkgs; [ kopia sqlite postgresql sudo findutils coreutils gawk ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      EnvironmentFile = "/root/.config/kopia/secret.env";
    };

    script = ''
      START_TIME=$(date +%s)
      JSON_PATH="/var/www/homepage/kopia-stats.json"
      mkdir -p $(dirname $JSON_PATH)

      generate_dashboard() {
        EXIT_CODE=$?
        END_TIME=$(date +%s)
        
        DURATION=$((END_TIME - START_TIME))
        MINS=$((DURATION / 60))
        SECS=$((DURATION % 60))
        
        LAST_RUN=$(date +"%d/%m - %H:%M")

        if [ $EXIT_CODE -eq 0 ]; then
          STATUS="Success"
          SIZE=$(${pkgs.coreutils}/bin/du -sh /mnt/disk1/backups/kopia | ${pkgs.gawk}/bin/awk '{print $1}')
        else
          STATUS="Failure"
          SIZE="Unknown"
        fi

        echo "{\"status\": \"$STATUS\", \"size\": \"$SIZE\", \"last_run\": \"$LAST_RUN\", \"duration\": \"''${MINS}m ''${SECS}s\"}" > $JSON_PATH

        chmod 644 $JSON_PATH
        chmod 755 /var/www/homepage
      }

      trap generate_dashboard EXIT
      set -e
      DUMP_DIR="/mnt/disk1/backups/dumps"
      mkdir -p $DUMP_DIR

      # --- Databases extraction ---
      
      # Vaultwarden & Paperless
      sqlite3 /var/lib/vaultwarden/db.sqlite3 ".backup '$DUMP_DIR/vaultwarden.db'"
      sqlite3 /var/lib/paperless/db.sqlite3 ".backup '$DUMP_DIR/paperless.db'"
      
      # Immich (PostgreSQL)
      sudo -u postgres pg_dump immich > $DUMP_DIR/immich_db.sql

      # Actual Budget
      mkdir -p $DUMP_DIR/actual-budget
      ACTUAL_DIR="/var/lib/actual" # À adapter selon ton installation
      if [ -d "$ACTUAL_DIR" ]; then
        find "$ACTUAL_DIR" -type f -name "*.sqlite" | while read -r db_path; do
          # Recrée l'arborescence des sous-dossiers dans le dump
          rel_path="''${db_path#$ACTUAL_DIR/}"
          mkdir -p "$DUMP_DIR/actual-budget/$(dirname "$rel_path")"
          sqlite3 "$db_path" ".backup '$DUMP_DIR/actual-budget/$rel_path'"
        done
      fi


      # --- KOPIA ---
      
      TARGETS="
        $DUMP_DIR
        $ACTUAL_DIR

        /var/lib/immich
        /var/lib/paperless
        /var/lib/syncthing/Sync/01-PROJECTS
        /var/lib/syncthing/Sync/02-AREAS
        /var/lib/syncthing/Sync/03-RESSOURCES
        /var/lib/syncthing/Sync/04-ARCHIVES

        
        /mnt/disk1/backups/github
        /etc/nixos
      "

      kopia repository connect filesystem --path /mnt/disk1/backups/kopia
      kopia snapshot create $TARGETS

      kopia policy set --global \
        --keep-latest 5 \
        --keep-hourly 0 \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 6 \
        --keep-annual 1 \
        --compression=zstd
      
      rm -rf $DUMP_DIR/*
      kopia maintenance run

      kopia repository sync-to b2 \
        --bucket="server1-nixos-backup" \
        --key-id="$B2_KEY_ID" \
        --key="$B2_APP_KEY"
    '';
  };

  systemd.timers.kopia-server-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}