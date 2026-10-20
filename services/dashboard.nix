{config, pkgs, ...}:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    allowedHosts = "192.168.42.200:8082,100.64.0.2:8082";

    widgets = [
      {
        greeting = {
          text_size = "xl";
          text = "Server1-NixOS";
        };
      }
      {
        resources = {
          cpu = true;
          units = "metric";
          cputemp = true;
          tempmin = 0;
          tempmax = 100;
          memory = true;
          disk = [ "/" "/mnt/disk1" ];
        };
      }
    ];

    services = [
      {
        "Infrastructure" = [
          # {
          #   "AdGuard Home" = {
          #     icon = "adguard-home.svg";
          #     href = "http://192.168.42.200:3000";
          #     ping = "http://127.0.0.1:3000";
          #     widget = {
          #       type = "adguard";
          #       url = "http://192.168.42.200:3000";
          #       username = "admin";
          #       password = "@uXB1bJKEG94EaO#";
          #     };
          #   };
          # }
          {
            "Backup Kopia" = {
              icon = "kopia.png";
              href = "https://secure.backblaze.com/b2_buckets.htm";
              widget = {
                type = "customapi";
                url = "http://localhost:8081/backup-status.json";
                mappings = [
                  # {
                  #   field = "github_sync";
                  #   label = "Github Sync";
                  # }
                  {
                    field = "databases_dump";
                    label = "Databases Dump";
                  }
                  {
                    field = "kopia_snapshot";
                    label = "Kopia Snapshot";
                  }
                  {
                    field = "sync_cloud";
                    label = "Sync Cloud";
                  }
                  {
                    field = "size";
                    label = "Size";
                  }
                  
                ];
              };
            };
          }
        ];
      }
      {
        "Utilities" = [
          {
            "Syncthing" = {
              icon = "syncthing.svg";
              href = "http://192.168.42.200:8384";
              ping = "http://127.0.0.1:8384";
            };
          }
          {
            "File Browser" = {
              icon = "filebrowser.svg";
              href = "https://files.bhr-sys.com";
              ping = "http://127.0.0.1:8080";
            };
          }
          {
            "Immich" = {
              icon = "immich.svg";
              href = "https://immich.bhr-sys.com";
              ping = "http://127.0.0.1:2283";
            };
          }
          {
            "Actual Budget" = {
              icon = "actual-budget.svg";
              href = "https://budget.bhr-sys.com";
              ping = "http://127.0.0.1:5006";
            };
          }
          {
            "Paperless Ngx" = {
              icon = "paperless-ngx.svg";
              href = "https://paperless.bhr-sys.com";
              ping = "http://127.0.0.1:28981";
            };
          }
          {
            "Vaultwarden" = {
              icon = "vaultwarden.svg";
              href = "https://vault.bhr-sys.com";
              ping = "http://127.0.0.1:8222";
            };
          }
        ];
      }
      {
        "Media" = [
          {
            "Radarr" = {
              icon = "radarr.svg";
              href = "https://radarr.bhr-sys.com";
              ping = "http://127.0.0.1:7878";
              widget = {
                type = "radarr";
                url = "http://127.0.0.1:7878";
                key = "{{HOMEPAGE_VAR_RADARR_API}}";
                fields = [ "movies" "wanted" "queued" ];
              };
            };
          }
          {
            "Sonarr" = {
              icon = "sonarr.svg";
              href = "https://sonarr.bhr-sys.com"; 
              ping = "http://127.0.0.1:8989"; 
              widget = {
                type = "sonarr";
                url = "http://127.0.0.1:8989";
                key = "{{HOMEPAGE_VAR_SONARR_API}}";
                fields = [ "series" "wanted" "queued" ];
              };
            };
          }
          {
            "Prowlarr" = {
              icon = "prowlarr.svg";
              href = "http://192.168.42.200:9696"; 
              ping = "http://127.0.0.1:9696"; 
            };
          }
          {
            "Bazarr" = {
              icon = "bazarr.svg";
              href = "http://192.168.42.200:6767"; 
              ping = "http://127.0.0.1:6767"; 
            };
          }
          {
            "Transmission" = {
              icon = "transmission.svg";
              href = "http://192.168.42.200:9091";
              ping = "http://127.0.0.1:9091";
            };
          }
          {
            "Jellyfin" = {
              icon = "jellyfin.svg";
              href = "https://jellyfin.bhr-sys.com";
              ping = "http://127.0.0.1:8096";
            };
          }
          {
            "Seerr" = {
              icon = "overseerr.svg";
              href = "https://seerr.bhr-sys.com";
              ping = "http://127.0.0.1:5055";
            };
          }
          {
            "Media Cleaner" = {
              icon = "si-jellyfin";
              href = "http://192.168.42.200:8081/cleaner.log";
              widget = {
                type = "customapi";
                url = "http://localhost:8081/cleaner.json";
                mappings = [
                  {
                    field = "space_before_trigger_gb";
                    label = "Margin GB";
                  }
                ];
              };
            };
          }
        ];
      }
    ];
  };
}