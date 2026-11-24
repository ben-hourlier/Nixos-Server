{ config, pkgs, ... }:

let
  githubRepos = [
    "git@github.com:ben-hourlier/Benflix3.git"
    "git@github.com:ben-hourlier/Digital-Brain.git"
    "git@github.com:ben-hourlier/Drill-Library.git"
    "git@github.com:ben-hourlier/N7Dev.git"
    "git@github.com:ben-hourlier/Nixos-Workstations.git"
    "git@github.com:ben-hourlier/Nixos-Server.git"
    "git@github.com:ben-hourlier/wip.git"

    "git@github.com:bhr-tools/Calendar"
    "git@github.com:bhr-tools/Capture"
    "git@github.com:bhr-tools/Dictee"
    "git@github.com:bhr-tools/Expense-Report-Creator.git"
    "git@github.com:bhr-tools/Focus"
    "git@github.com:bhr-tools/GetDone"
    "git@github.com:bhr-tools/Inventory"
    "git@github.com:bhr-tools/Mail"
    "git@github.com:bhr-tools/Meals"
    "git@github.com:bhr-tools/Project"
    "git@github.com:bhr-tools/Workspace-Manager"
  ];

  dumpDir = "/mnt/disk1/backups/dumps";
  canaryDir = "/var/lib/backup-canary";

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

      # Self-hosted apps (GetDone, Focus, Calendar, Inventory, Meals, Project, CV):
      # one SQLite database per instance directory, so new instances are picked up as is.
      for db in /var/lib/getdone-*/*.db /var/lib/focus-*/*.db /var/lib/calendar-*/*.db /var/lib/inventory-*/*.db /var/lib/meals-*/*.db /var/lib/project-*/*.db /var/lib/cv/*.db; do
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
        # Time of the last success, read by services/health.nix (survives reboots,
        # unlike the units' own timestamps).
        mkdir -p /var/lib/backup-status
        date +%s > "/var/lib/backup-status/$STEP"
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
      
      # One failing repository must not stop the others; the service still
      # fails at the end so the status shows it.
      failed=""
      ${pkgs.lib.concatMapStringsSep "\n" (repo: ''
        repo_name=$(basename "${repo}" .git)
        if [ -d "$repo_name.git" ]; then
          git -C "$repo_name.git" remote update || failed="$failed $repo_name"
        else
          git clone --mirror "${repo}" "$repo_name.git" || failed="$failed $repo_name"
        fi
      '') githubRepos}
      if [ -n "$failed" ]; then
        echo "failed:$failed" >&2
        exit 1
      fi
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

      # Files attached in Inventory (invoices, manuals) and GetDone (tickets,
      # photos), and the PDFs sent with each application (CV); their databases are in the dumps.
      attachments=()
      for dir in /var/lib/inventory-*/attachments /var/lib/getdone-*/attachments /var/lib/cv/sent; do
        if [ -d "$dir" ]; then attachments+=("$dir"); fi
      done

      # Canary: a file whose content changes at every backup. kopia-verify-cloud
      # restores it from Backblaze and compares: that proves today's backup reached
      # the cloud and can be read back (a constant file would be deduplicated, and
      # restoring it would only prove that its first upload arrived).
      mkdir -p ${canaryDir}
      printf '%s %s\n' "$(date -Is)" "$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')" > ${canaryDir}/canary

      kopia snapshot create \
        ${canaryDir} \
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
  # 4b. Verification of the Backblaze copy, after each sync
  # --------------------------------------------------------------------
  # Read-only, through a connection of its own (--config-file), so the local
  # repository's connection is never touched. Three checks:
  #   - consistency: every block the snapshots refer to exists in the bucket;
  #   - sample: 2 % of the files, drawn at random, downloaded, decrypted and checked
  #     (the whole backup is covered within weeks; B2 egress is free up to three
  #     times the stored volume per month);
  #   - canary: today's canary restored and compared with the local one.
  # Its result is recorded like the other steps (verify_cloud), so health.nix sees it.
  systemd.services.kopia-verify-cloud = {
    description = "Vérification de la copie Kopia sur Backblaze B2";
    after = [ "kopia-sync-cloud.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [ kopia coreutils diffutils jq ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      # KOPIA_PASSWORD, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.
      EnvironmentFile = config.sops.secrets.kopia.path;
      StateDirectory = "kopia-verify";
      ExecStopPost = [
        "${updateStatusScript}/bin/update-backup-status verify_cloud"
      ];
    };

    script = ''
      set -euo pipefail
      cloud=(kopia --config-file=/var/lib/kopia-verify/repository.config)

      "''${cloud[@]}" repository connect s3 --readonly \
        --bucket="server1-nixos-backup" \
        --endpoint="s3.eu-central-003.backblazeb2.com"

      "''${cloud[@]}" snapshot verify --verify-files-percent=2 --file-parallelism=4

      latest=$("''${cloud[@]}" snapshot list ${canaryDir} --json | jq -r 'max_by(.startTime) | .id')
      restored=$(mktemp -d)
      trap 'rm -rf "$restored"' EXIT
      "''${cloud[@]}" snapshot restore "$latest" "$restored"
      if ! cmp -s "$restored/canary" ${canaryDir}/canary; then
        echo "canary: the copy on Backblaze is not today's backup" >&2
        exit 1
      fi
      echo "canary: OK ($(cat ${canaryDir}/canary))"
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
  # On enchaîne : dump -> snapshot -> sync cloud -> vérification cloud
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
        "${pkgs.systemd}/bin/systemctl start --wait kopia-verify-cloud.service"
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

  programs.fuse.enable = true;
}