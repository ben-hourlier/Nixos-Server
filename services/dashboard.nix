{config, pkgs, ...}:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    
    # Autorisations d'accès (Anti-usurpation)
    allowedHosts = "192.168.42.200:8082,100.64.0.2:8082";

    # 1. EN-TÊTE MINIMALISTE (Ressources serveur uniquement)
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

    # 2. VOS SERVICES (Interface propre, sans API ni mots de passe en clair)
    services = [
      {
        "Infrastructure" = [
          {
            "Scrutiny" = {
              icon = "scrutiny.svg";
              href = "http://192.168.42.200:8085";
              ping = "http://127.0.0.1:8085";
              widget = {
                type = "scrutiny";
                url = "http://192.168.42.200:8085";
              };
            };
          }

          {
            "AdGuard Home" = {
              icon = "adguard-home.svg";
              href = "http://192.168.42.200:3000";
              ping = "http://127.0.0.1:3000";
              widget = {
                type = "adguard";
                url = "http://192.168.42.200:3000";
                username = "admin";
                password = "@uXB1bJKEG94EaO#";
              };
            };
          }

          {
            "Backup Kopia" = {
              icon = "kopia.png";
              href = "https://secure.backblaze.com/b2_buckets.htm";
              widget = {
                type = "customapi";
                url = "http://localhost:8081/kopia-stats.json";
                mappings = [
                  {
                    field = "status";
                    label = "Status";
                  }
                  {
                    field = "last_run";
                    label = "Last Run";
                  }
                  {
                    field = "size";
                    label = "Backup Size";
                  }
                  {
                    field = "duration";
                    label = "Duration";
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
              href = "http://192.168.42.200:8080";
              ping = "http://127.0.0.1:8080";
            };
          }

          {
            "Immich" = {
              icon = "immich.svg";
              href = "https://immich.jarvis-edith-ben.duckdns.org";
              ping = "http://127.0.0.1:2283";
            };
          }

          {
            "Actual Budget" = {
              icon = "actual-budget.svg";
              href = "https://budget.jarvis-edith-ben.duckdns.org";
              ping = "http://127.0.0.1:5006";
            };
          }

          {
            "Paperless Ngx" = {
              icon = "paperless-ngx.svg";
              href = "https://paperless.jarvis-edith-ben.duckdns.org";
              ping = "http://127.0.0.1:28981";
            };
          }

          {
            "Vaultwarden" = {
              icon = "vaultwarden.svg";
              href = "https://vault.jarvis-edith-ben.duckdns.org";
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
              href = "http://192.168.42.200:7878";
              ping = "http://127.0.0.1:7878";
              widget = {
                type = "radarr";
                url = "http://127.0.0.1:7878";
                key = "RADARR_API";
                fields = [ "movies" "wanted" "queued" ];
              };
            };
          }
          {
            "Sonarr" = {
              icon = "sonarr.svg";
              href = "http://192.168.42.200:8989"; 
              ping = "http://127.0.0.1:8989"; 
              widget = {
                type = "sonarr";
                url = "http://127.0.0.1:8989";
                key = "SONARR_API";
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
              href = "https://jarvis-edith-ben.duckdns.org";
              ping = "http://127.0.0.1:8096";
            };
          }
          {
            "Seerr" = {
              icon = "overseerr.svg";
              href = "https://seerr.jarvis-edith-ben.duckdns.org";
              ping = "http://127.0.0.1:5055";
            };
          }
        ];
      }
    ];
  };
}