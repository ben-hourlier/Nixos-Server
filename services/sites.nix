{ config, ... }:

# Everything the server exposes, one line each (mechanics in modules/homelab.nix).
#   - homelab.apps: my own apps, one instance per person. Declares the instance,
#     its reverse proxy (<app>.bhr-sys.com for me, <name>.<app>.bhr-sys.com for
#     the others) and its Homepage card.
#   - homelab.sites: everything else, with a reverse proxy when `port` is set
#     (domain defaults to <key>.bhr-sys.com) or a plain card when `domain = null`.
# `vpn = true`: only reachable from the tailnet (VPN required, at home too).
# App-specific settings (mail accounts, Project notes…) stay in utilities.nix.

{
  homelab = {
    domain = "bhr-sys.com";
    owner = "ben";
    tailnetIP = "100.64.0.2";
    # Homepage, row by row, left to right.
    rows = [ [ "Infrastructure" "Utilities" "Media" ] [ "Apps" "Shared" ] ];

    # --- My apps ---

    apps = {
      calendar = {
        iconPath = "/icons/icon.svg";
        instances.ben.port = 9880;
      };

      focus = {
        iconPath = "/icon.svg";
        instances = {
          ben.port = 8765;
          nina.port = 8766;
          raph.port = 8767;
          kilian.port = 8768;
        };
      };

      getdone = {
        title = "GetDone";
        iconPath = "/icons/icon.svg";
        instances = {
          ben.port = 9870;
          nina.port = 9871;
          oscar.port = 9872;
          kilian.port = 9873;
          vic.port = 9874;
        };
      };

      inventory = {
        iconPath = "/icons/icon.svg";
        instances.ben.port = 9900;
      };

      mail = {
        service = "webmail";
        iconPath = "/icons/icon.svg";
        instances.ben = { port = 9890; vpn = true; };
      };

      meals = {
        iconPath = "/icons/icon.svg";
        instances.ben.port = 9920;
      };

      project = {
        iconPath = "/icons/icon.svg";
        instances.ben = { port = 9930; vpn = true; };
      };
    };

    sites = {

      # --- My single-instance apps ---

      cv = { title = "CV"; icon = "https://cv.bhr-sys.com/icons/icon.svg"; port = config.services.cv.port; vpn = true; };
      dictee = {
        title = "Dictée";
        icon = "https://dictee.bhr-sys.com/icons/icon.svg";
        port = config.services.dictee.port;
        # DICTEE_HASH='<bcrypt from `caddy hash-password`>' in caddy-env
        caddy = ''
          request_body {
            max_size 200MB
          }
          # The icon stays public, for home screens and Homepage.
          @locked not path /icons/*
          basic_auth @locked {
            dictee {$DICTEE_HASH}
          }
        '';
      };
      # Caddy virtual host declared by the wip module itself.
      wip = { title = "Wip"; icon = "https://wip.bhr-sys.com/favicon.svg"; ping = "https://wip.bhr-sys.com"; };

      # --- Infrastructure ---

      vpn = { title = "Headscale"; group = "Infrastructure"; icon = "headscale.svg"; port = 9080; };
      kopia-status = {
        title = "Backup Kopia";
        group = "Infrastructure";
        icon = "kopia.png";
        domain = null;
        href = "https://secure.backblaze.com/b2_buckets.htm";
        widget = {
          type = "customapi";
          url = "http://localhost:8081/backup-status.json";
          mappings = [
            { field = "github_sync"; label = "Github Sync"; }
            { field = "databases_dump"; label = "Databases Dump"; }
            { field = "kopia_snapshot"; label = "Kopia Snapshot"; }
          ];
        };
      };
      kopia-cloud = {
        title = "Backup Kopia";
        group = "Infrastructure";
        icon = "kopia.png";
        domain = null;
        href = "https://secure.backblaze.com/b2_buckets.htm";
        widget = {
          type = "customapi";
          url = "http://localhost:8081/backup-status.json";
          mappings = [
            { field = "sync_cloud"; label = "Sync Cloud"; }
            { field = "verify_cloud"; label = "Verify Cloud"; }
            { field = "size"; label = "Size"; }
          ];
        };
      };

      # --- Utilities ---

      budget = { title = "Actual Budget"; group = "Utilities"; icon = "actual-budget.svg"; port = config.services.actual.settings.port; };
      files = { title = "File Browser"; group = "Utilities"; icon = "filebrowser.svg"; port = 8080; vpn = true; };
      immich = { title = "Immich"; group = "Utilities"; icon = "immich.svg"; port = config.services.immich.port; };
      paperless = { title = "Paperless Ngx"; group = "Utilities"; icon = "paperless-ngx.svg"; port = config.services.paperless.port; vpn = true; };
      syncthing = { title = "Syncthing"; group = "Utilities"; icon = "syncthing.svg"; domain = null; href = "http://192.168.42.200:8384"; ping = "http://127.0.0.1:8384"; };
      vault = { title = "Vaultwarden"; group = "Utilities"; icon = "vaultwarden.svg"; port = config.services.vaultwarden.config.ROCKET_PORT; };

      # --- Media ---

      jellyfin = { title = "Jellyfin"; group = "Media"; icon = "jellyfin.svg"; port = 8096; };
      seerr = { title = "Seerr"; group = "Media"; icon = "overseerr.svg"; port = 5055; };
      radarr = {
        title = "Radarr";
        group = "Media";
        icon = "radarr.svg";
        port = 7878;
        vpn = true;
        widget = {
          type = "radarr";
          url = "http://127.0.0.1:7878";
          key = "{{HOMEPAGE_VAR_RADARR_API}}";
          fields = [ "movies" "wanted" "queued" ];
        };
      };
      sonarr = {
        title = "Sonarr";
        group = "Media";
        icon = "sonarr.svg";
        port = 8989;
        vpn = true;
        widget = {
          type = "sonarr";
          url = "http://127.0.0.1:8989";
          key = "{{HOMEPAGE_VAR_SONARR_API}}";
          fields = [ "series" "wanted" "queued" ];
        };
      };
      prowlarr = { title = "Prowlarr"; group = "Media"; icon = "prowlarr.svg"; domain = null; href = "http://192.168.42.200:9696"; ping = "http://127.0.0.1:9696"; };
      bazarr = { title = "Bazarr"; group = "Media"; icon = "bazarr.svg"; domain = null; href = "http://192.168.42.200:6767"; ping = "http://127.0.0.1:6767"; };
      transmission = { title = "Transmission"; group = "Media"; icon = "transmission.svg"; domain = null; href = "http://192.168.42.200:9091"; ping = "http://127.0.0.1:9091"; };
      media-cleaner = {
        title = "Media Cleaner";
        group = "Media";
        icon = "si-jellyfin";
        domain = null;
        href = "http://192.168.42.200:8081/cleaner.log";
        widget = {
          type = "customapi";
          url = "http://localhost:8081/cleaner.json";
          mappings = [ { field = "space_before_trigger_gb"; label = "Margin GB"; } ];
        };
      };
    };
  };
}
