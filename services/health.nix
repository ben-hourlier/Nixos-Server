{ config, lib, pkgs, ... }:

# Server health, minimal: every 5 minutes a script checks what matters and writes
# three JSON files next to the backup status (served by Caddy on :8081):
#   - health.json: { generated; problems = [ { name; detail; } ]; items; }.
#     QuickShell on the workstations shows an icon only while problems is not empty
#     (or the file cannot be read, or is stale). items is what Homepage lists.
#   - disks.json: the SMART figures worth reading, one entry per disk.
#   - usage.json: for each site with usage = true, when it was last used.
# Nothing is sent anywhere: the workstations come and read.

let
  out = "/var/www/homepage";
  state = "/var/lib/health";

  # What to check, taken from the registry (services/sites.nix): a new app is
  # watched without touching this file.
  sites = lib.attrValues config.homelab.sites;
  targets = pkgs.writeText "health-targets.json" (builtins.toJSON {
    pings = map (s: { inherit (s) title; url = s.ping; }) (lib.filter (s: s.ping != null) sites);
    usage = map (s: {
      key = s.id;
      log = "${config.services.caddy.logDir}/access-${s.domain}.log";
    }) (lib.filter (s: s.usage && s.domain != null) sites);
    # The steps of backup.nix and the units that run them.
    backups = [
      { step = "github_sync"; unit = "github-sync"; }
      { step = "databases_dump"; unit = "backup-dump-databases"; }
      { step = "kopia_snapshot"; unit = "kopia-snapshot"; }
      { step = "sync_cloud"; unit = "kopia-sync-cloud"; }
      { step = "verify_cloud"; unit = "kopia-verify-cloud"; }
    ];
    # The pipeline runs daily: a success older than 26 h means a run was missed.
    maxBackupAge = 26 * 3600;
  });

  healthScript = pkgs.writeShellApplication {
    name = "health-check";
    runtimeInputs = with pkgs; [ coreutils curl gawk jq smartmontools systemd ];
    text = ''
      set -euo pipefail
      targets=${targets}
      now=$(date +%s)
      mkdir -p ${out} ${state}

      problems='[]'
      problem() { # name detail
        problems=$(jq -c --arg n "$1" --arg d "$2" '. + [ { name: $n, detail: $d } ]' <<<"$problems")
      }

      # --- 1. Services that failed (backups, apps, anything systemd runs) ---
      while read -r unit _; do
        problem "Service failed" "$unit"
      done < <(systemctl list-units --state=failed --plain --no-legend)

      # --- 2. Backups: the last success of each step is recent enough ---
      max_age=$(jq -r .maxBackupAge "$targets")
      while IFS=$'\t' read -r step unit; do
        last=$(cat "/var/lib/backup-status/$step" 2>/dev/null || true)
        # Before backup.nix recorded it, fall back on the unit's last successful exit.
        if [ -z "$last" ] && [ "$(systemctl show -P Result "$unit")" = success ]; then
          last=$(systemctl show -P ExecMainExitTimestamp --timestamp=unix "$unit" | tr -d @)
        fi
        if [ -z "$last" ]; then
          problem "Backup $step" "no success recorded"
        elif (( now - last > max_age )); then
          problem "Backup $step" "last success $(( (now - last) / 3600 )) h ago"
        fi
      done < <(jq -r '.backups[] | [.step, .unit] | @tsv' "$targets")

      # --- 3. Disks: SMART figures, and what in them is a problem ---
      disks='[]'
      while read -r dev type; do
        # smartctl's exit status is a bit mask that is often non-zero on a healthy
        # disk (an old entry in the error log): the JSON is what counts.
        report=$(smartctl -a -j -d "$type" "$dev" || true)
        disk=$(jq -c --arg dev "$dev" '
          def attr($id): (.ata_smart_attributes.table // []) | map(select(.id == $id)) | .[0].raw.value;
          # SATA SSD wear: normalized value of 202 (Crucial, Micron) or 231 (others) = % of life left.
          def life_left: (.ata_smart_attributes.table // []) | map(select(.id == 202 or .id == 231)) | .[0].value;
          .nvme_smart_health_information_log as $n
          | {
              device: $dev,
              model: .model_name,
              passed: .smart_status.passed,
              temperature: .temperature.current,
              power_on_hours: .power_on_time.hours,
              percentage_used: $n.percentage_used,
              available_spare: $n.available_spare,
              spare_threshold: $n.available_spare_threshold,
              media_errors: $n.media_errors,
              critical_warning: $n.critical_warning,
              reallocated: attr(5),
              pending: attr(197),
              uncorrectable: attr(198),
              crc_errors: attr(199),
              life_left: life_left,
              last_self_test_passed: (
                .ata_smart_self_test_log.standard.table[0].status.passed
                // (if .nvme_self_test_log.table then .nvme_self_test_log.table[0].self_test_result.value == 0 else null end)
              )
            }
          | with_entries(select(.value != null))
          | .problems = [
              (if .passed == false then "SMART overall health: FAILED" else empty end),
              (if (.pending // 0) > 0 then "\(.pending) sectors pending reallocation" else empty end),
              (if (.uncorrectable // 0) > 0 then "\(.uncorrectable) uncorrectable sectors" else empty end),
              (if (.critical_warning // 0) != 0 then "NVMe critical warning \(.critical_warning)" else empty end),
              (if (.media_errors // 0) > 0 then "\(.media_errors) media errors" else empty end),
              (if .available_spare != null and .spare_threshold != null and .available_spare <= .spare_threshold
                then "spare blocks at \(.available_spare) %, threshold \(.spare_threshold) %" else empty end),
              (if (.percentage_used // 0) >= 90 then "\(.percentage_used) % of rated endurance used" else empty end),
              (if .life_left != null and .life_left <= 10 then "\(.life_left) % of life left" else empty end),
              (if (.temperature // 0) >= 70 then "\(.temperature) °C" else empty end),
              (if .last_self_test_passed == false then "last self-test failed" else empty end)
            ]
          | .summary = (
              [ (if .problems == [] then "OK" else "PROBLEM" end),
                (if .percentage_used != null then "\(.percentage_used) % worn" else empty end),
                (if .life_left != null then "\(100 - .life_left) % worn" else empty end),
                (if .reallocated != null then "\(.reallocated) realloc." else empty end),
                (if .temperature != null then "\(.temperature) °C" else empty end) ]
              | join(" · "))
          ' <<<"$report")
        disks=$(jq -c --argjson d "$disk" '. + [ $d ]' <<<"$disks")
        while IFS= read -r p; do
          problem "Disk $dev" "$p"
        done < <(jq -r '.problems[]' <<<"$disk")
      done < <(smartctl --scan -j | jq -r '.devices[] | "\(.name) \(.type)"')

      # --- 4. Space left on each filesystem ---
      while read -r pct target; do
        pct=''${pct%\%}
        if (( pct >= 90 )); then problem "Disk space" "$target at $pct %"; fi
      done < <(df --output=pcent,target -x tmpfs -x devtmpfs -x efivarfs -x overlay | tail -n +2)

      # --- 5. Every site answers (any HTTP status counts: the service is up) ---
      while IFS=$'\t' read -r title url; do
        code=$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' "$url" || true)
        if [ "$code" = 000 ]; then problem "Down" "$title"; fi
      done < <(jq -r '.pings[] | [.title, .url] | @tsv' "$targets")

      # --- 6. Usage: the last write request (POST, PUT, PATCH, DELETE answered with
      # 2xx/3xx) in each site's Caddy access log. Reads only what was appended since
      # the last run, and keeps the result: it survives the logs' rotation. ---
      usage_state="${state}/usage.json"
      [ -f "$usage_state" ] || echo '{}' > "$usage_state"
      memory=$(cat "$usage_state")
      while IFS=$'\t' read -r key log; do
        [ -f "$log" ] || continue
        size=$(stat -c %s "$log")
        inode=$(stat -c %i "$log")
        read -r last offset seen_inode < <(jq -r --arg k "$key" '.[$k] // {} | "\(.last // 0) \(.offset // 0) \(.inode // 0)"' <<<"$memory")
        # A new file (rotation) or a shorter one: start from the beginning.
        if [ "$inode" != "$seen_inode" ] || (( size < offset )); then offset=0; fi
        found=$(tail -c +"$((offset + 1))" "$log" \
          | jq -rR 'fromjson? | select((.request.method | IN("POST", "PUT", "PATCH", "DELETE")) and .status >= 200 and .status < 400) | .ts | floor' \
          | tail -n 1)
        if [ -n "$found" ] && (( found > last )); then last=$found; fi
        memory=$(jq -c --arg k "$key" --argjson l "$last" --argjson o "$size" --argjson i "$inode" \
          '.[$k] = { last: $l, offset: $o, inode: $i }' <<<"$memory")
      done < <(jq -r '.usage[] | [.key, .log] | @tsv' "$targets")
      echo "$memory" > "$usage_state.tmp" && mv "$usage_state.tmp" "$usage_state"

      # --- Results, each written atomically (a reader never sees half a file) ---
      write() { # file json
        echo "$2" > "${out}/$1.tmp"
        chmod 644 "${out}/$1.tmp"
        mv "${out}/$1.tmp" "${out}/$1"
      }

      write usage.json "$(jq -c --argjson now "$now" --slurpfile t "$targets" '
        . as $m
        | [ $t[0].usage[].key ]
        | map({ key: ., value: (
            ($m[.].last // 0) as $last
            | if $last == 0 then "none yet"
              else (($now - $last) / 86400 | floor) as $d
              | if $d == 0 then "today" elif $d == 1 then "yesterday" else "\($d) days ago" end
              end) })
        | from_entries' <<<"$memory")"

      write disks.json "$(jq -c '{ disks: ., items: map({ name: "\(.device) · \(.model // "?")", detail: .summary }) }' <<<"$disks")"

      write health.json "$(jq -c --argjson now "$now" '{
        generated: $now,
        problems: .,
        items: (if . == [] then [ { name: "All checks passed", detail: ($now | strflocaltime("%H:%M")) } ] else . end)
      }' <<<"$problems")"
    '';
  };
in
{
  # SMART self-tests run by smartd: short every night at 02:00, long on Saturdays at
  # 03:00 (-s), automatic offline data collection (-o) and attribute autosave (-S).
  # Its warnings to terminals (wall) are off: health.json carries them.
  services.smartd = {
    enable = true;
    defaults.autodetected = "-a -o on -S on -s (S/../.././02|L/../../6/03)";
    notifications.wall.enable = false;
  };

  # smartctl for reading the disks by hand (see the disks card, or `sudo smartctl -a /dev/sda`).
  environment.systemPackages = [ pkgs.smartmontools ];

  systemd.services.health-check = {
    description = "Server health check (health.json, disks.json, usage.json)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root"; # smartctl and the Caddy logs need it
      ExecStart = "${healthScript}/bin/health-check";
    };
  };

  systemd.timers.health-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
    };
  };

  # The two cards of the dashboard; the last use is shown on each shared instance's card.
  homelab.sites = {
    health = {
      title = "Health";
      group = "Infrastructure";
      icon = "mdi-heart-pulse";
      domain = null;
      href = "http://192.168.42.200:8081/health.json";
      widget = {
        type = "customapi";
        url = "http://localhost:8081/health.json";
        refreshInterval = 60000;
        display = "dynamic-list";
        mappings = { items = "items"; name = "name"; label = "detail"; };
      };
    };
    disks = {
      title = "Disks";
      group = "Infrastructure";
      icon = "mdi-harddisk";
      domain = null;
      href = "http://192.168.42.200:8081/disks.json";
      widget = {
        type = "customapi";
        url = "http://localhost:8081/disks.json";
        refreshInterval = 300000;
        display = "dynamic-list";
        mappings = { items = "items"; name = "name"; label = "detail"; };
      };
    };
  };
}
