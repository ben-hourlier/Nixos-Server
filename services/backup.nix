{ config, pkgs, ... }:

let
  githubRepos = [
    "git@github.com:jarvis-ed1th/FocusOS.git"
    "git@github.com:jarvis-ed1th/Digital-Brain.git"
    "git@github.com:jarvis-ed1th/expense-report-creator.git"
    "git@github.com:jarvis-ed1th/server1-nixos.git"
  ];

  dumpDir = "/mnt/disk1/backups/dumps";

  # Script d'extraction des bases de données avec validation ShellCheck intégrée
  dumpScript = pkgs.writeShellApplication {
    name = "backup-dump-databases";
    runtimeInputs = with pkgs; [ sqlite postgresql coreutils findutils util-linux ];
    text = ''
      set -euo pipefail
      mkdir -p "${dumpDir}/actual-budget"

      # Vaultwarden & Paperless
      if [ -f /var/lib/vaultwarden/db.sqlite3 ]; then
        sqlite3 /var/lib/vaultwarden/db.sqlite3 ".backup '${dumpDir}/vaultwarden.db'"
      fi

      if [ -f /var/lib/paperless/db.sqlite3 ]; then
        sqlite3 /var/lib/paperless/db.sqlite3 ".backup '${dumpDir}/paperless.db'"
      fi

      # Immich (PostgreSQL)
      runuser -u postgres pg_dump immich > "${dumpDir}/immich_db.sql"

      # Actual Budget
      actual_dir="/var/lib/actual"
      if [ -d "$actual_dir" ]; then
        find "$actual_dir" -type f -name "*.sqlite" | while IFS= read -r db_path; do
          rel_path="''${db_path#"$actual_dir"/}"
          target_dir="${dumpDir}/actual-budget/$(dirname "$rel_path")"
          mkdir -p "$target_dir"
          sqlite3 "$db_path" ".backup '$target_dir/$(basename "$rel_path")'"
        done
      fi

      # Self-hosted apps (GetDone, Focus, Calendar, Inventory): one SQLite
      # database per instance directory, so new instances are picked up as is.
      for db in /var/lib/getdone-*/*.db /var/lib/focus-*/*.db /var/lib/calendar-*/*.db /var/lib/inventory-*/*.db; do
        [ -f "$db" ] || continue
        app_dir="$(basename "$(dirname "$db")")"
        mkdir -p "${dumpDir}/apps/$app_dir"
        sqlite3 "$db" ".backup '${dumpDir}/apps/$app_dir/$(basename "$db")'"
      done
    '';
  };

  updateStatusScript = pkgs.writeShellApplication {
    name = "update-backup-status";
    runtimeInputs = with pkgs; [ jq coreutils ];
    text = ''
      set -euo pipefail

      STEP="''${1:-unknown}"
      RESULT="''${SERVICE_RESULT:-unknown}"
      JSON_PATH="/var/www/homepage/backup-status.json"
      TMP_JSON="''${JSON_PATH}.tmp"
      NOW=$(date +"%d/%m - %H:%M")

      STATUS="$NOW ❌"
      SIZE="Unknown"
      if [ "$RESULT" = "success" ]; then
        STATUS="$NOW ✅"
        if [ "$STEP" = "kopia_snapshot" ] && [ -d /mnt/disk1/backups/kopia ]; then
          SIZE=$(du -sh /mnt/disk1/backups/kopia | cut -f1)
        fi
      fi

      mkdir -p "$(dirname "$JSON_PATH")"

      if [ ! -f "$JSON_PATH" ]; then
        echo '{}' > "$JSON_PATH"
      fi
      

      # Met à jour la clé de l'étape et recalcule le statut global
      jq --arg step "$STEP" \
         --arg status "$STATUS" \
         --arg size "$SIZE" \
         '
         .[$step] = $status
         | (if $size != "Unknown" then .size = $size else . end)
         ' "$JSON_PATH" > "$TMP_JSON"

      mv "$TMP_JSON" "$JSON_PATH"
      chmod 644 "$JSON_PATH"
    '';
  };

in
{
  # --------------------------------------------------------------------
  # 1. Synchronisation Git
  # --------------------------------------------------------------------
  systemd.services.github-sync = {
    description = "Synchronisation miroir des dépôts GitHub";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [ git openssh coreutils ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStopPost = [
        "${updateStatusScript}/bin/update-backup-status github_sync"
      ];
    };
    script = ''
      set -euo pipefail
      mkdir -p /mnt/disk1/backups/github
      cd /mnt/disk1/backups/github
      
      ${pkgs.lib.concatMapStringsSep "\n" (repo: ''
        repo_name=$(basename "${repo}" .git)
        if [ -d "$repo_name.git" ]; then
          git -C "$repo_name.git" remote update
        else
          git clone --mirror "${repo}" "$repo_name.git"
        fi
      '') githubRepos}
    '';
  };

  # --------------------------------------------------------------------
  # 2. Dump des bases de données
  # --------------------------------------------------------------------
  systemd.services.backup-dump-databases = {
    description = "Extraction à chaud des bases de données";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${dumpScript}/bin/backup-dump-databases";
      ExecStopPost = [
        "${updateStatusScript}/bin/update-backup-status databases_dump"
      ];
    };
  };

  # --------------------------------------------------------------------
  # 3. Snapshot local Kopia
  # --------------------------------------------------------------------
  systemd.services.kopia-snapshot = {
    description = "Snapshot local Kopia";
    requires = [ "backup-dump-databases.service" ];
    after = [ "backup-dump-databases.service" "mnt-disk1.mount" "github-sync.service" ];
    path = with pkgs; [ kopia coreutils jq ];
    
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      EnvironmentFile = config.sops.secrets.kopia.path;
      ExecStopPost = [
        "${updateStatusScript}/bin/update-backup-status kopia_snapshot"
      ];
    };

    script = ''
      set -euo pipefail
      START_TIME=$(date +%s)
      JSON_PATH="/var/www/homepage/kopia-stats.json"

      kopia repository connect filesystem --path /mnt/disk1/backups/kopia

      # Files attached in Inventory (invoices, manuals); their database is in the dumps.
      attachments=()
      for dir in /var/lib/inventory-*/attachments; do
        if [ -d "$dir" ]; then attachments+=("$dir"); fi
      done

      kopia snapshot create \
        "${dumpDir}" \
        "''${attachments[@]}" \
        /var/lib/actual \
        /var/lib/immich \
        /var/lib/paperless \
        /var/lib/syncthing/Sync/01-PROJECTS \
        /var/lib/syncthing/Sync/02-AREAS \
        /var/lib/syncthing/Sync/03-RESSOURCES \
        /var/lib/syncthing/Sync/04-ARCHIVES \
        /mnt/disk1/backups/github

      # Nettoyage des dumps temporaires
      rm -rf ${dumpDir}/*
    '';
  };

  # --------------------------------------------------------------------
  # 4. Synchronisation Cloud S3 / B2 (Isolée du snapshot)
  # --------------------------------------------------------------------
  systemd.services.kopia-sync-cloud = {
    description = "Synchronisation du dépôt Kopia vers Backblaze B2 (API S3)";
    after = [ "kopia-snapshot.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [ kopia ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      EnvironmentFile = config.sops.secrets.kopia.path;
      ExecStopPost = [
        "${updateStatusScript}/bin/update-backup-status sync_cloud"
      ];
    };

    script = ''
      set -euo pipefail
      kopia repository connect filesystem --path /mnt/disk1/backups/kopia

      # Synchronisation via le protocole S3 compatible Backblaze
      kopia repository sync-to s3 \
        --bucket="server1-nixos-backup" \
        --endpoint="s3.eu-central-003.backblazeb2.com" \
        --delete
    '';
  };

  # --------------------------------------------------------------------
  # 5. Maintenance hebdomadaire (Séparée du flux quotidien)
  # --------------------------------------------------------------------
  systemd.services.kopia-maintenance = {
    description = "Maintenance du dépôt Kopia (Purger les vieux blocs)";
    path = with pkgs; [ kopia ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      EnvironmentFile = config.sops.secrets.kopia.path;
    };
    script = ''
      set -euo pipefail
      kopia repository connect filesystem --path /mnt/disk1/backups/kopia
      kopia maintenance run --full
    '';
  };

  systemd.timers.kopia-maintenance = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 03:00";
      Persistent = true;
    };
  };

  # --------------------------------------------------------------------
  # 6. Timer principal de sauvegarde journalière
  # --------------------------------------------------------------------
  # On enchaîne : dump -> snapshot -> sync cloud
  systemd.services.backup-pipeline = {
    description = "Pipeline complet de sauvegarde journalière";
    wants = [ "github-sync.service" ];
    after = [ "github-sync.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.systemd}/bin/systemctl start --wait backup-dump-databases.service"
        "${pkgs.systemd}/bin/systemctl start --wait kopia-snapshot.service"
        "${pkgs.systemd}/bin/systemctl start --wait kopia-sync-cloud.service"
      ];
    };
  };

  systemd.timers.backup-pipeline = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:20:00";
      Persistent = true;
    };
  };
}