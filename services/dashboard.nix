{config, pkgs, ...}:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    
    # Autorisations d'accès (Anti-usurpation)
    allowedHosts = "192.168.42.200:8082,dashboard.jarvis-edith-ben.duckdns.org"; 

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
          memory = true;
          disk = "/";
        };
      }
    ];

    # 2. VOS SERVICES (Interface propre, sans API ni mots de passe en clair)
    services = [
      {
        "Infrastructure" = [
          {
            "Uptime Kuma" = {
              icon = "adguard-home.svg";
              href = "http://127.0.0.1:3001";
              widget = {
                type = "uptimekuma";
                # L'adresse interne pour que Homepage contacte Kuma directement
                url = "http://127.0.0.1:3001";
                # Le slug (ou l'ID) que tu as récupéré à l'étape 1
                slug = "default";
              };
            };
          }

          {
            "AdGuard Home" = {
              icon = "adguard-home.svg";
              href = "http://100.64.0.1:3000";
              description = "Bloqueur de publicités & DNS";
            };
          }

          {
            "Actual" = {
              icon = "actual-budget.svg";
              href = "https://budget.jarvis-edith-ben.duckdns.org";
              description = "Budget";
            };
          }
        ];
      }
      {
        "Multimédia" = [
          {
            "Jellyfin" = {
              icon = "jellyfin.svg";
              href = "http://192.168.42.200:8096";
              description = "Plateforme de streaming maison";
              ping = "http://127.0.0.1:8096";
            };
          }
        ];
      }
      {
        "Automatisation" = [
          {
            "Radarr" = {
              icon = "radarr.svg";
              href = "http://192.168.42.200:7878";
              description = "Gestion des films";
            };
          }
          {
            "Sonarr" = {
              icon = "sonarr.svg";
              href = "http://192.168.42.200:8989"; 
              description = "Gestion des séries";
            };
          }
          {
            "Bazarr" = {
              icon = "bazarr.svg";
              href = "http://192.168.42.200:6767"; 
              description = "Gestion des sous-titres";
            };
          }
        ];
      }
      {
        "Téléchargements" = [
          {
            "Transmission" = {
              icon = "transmission.svg";
              href = "http://192.168.42.200:9091";
              description = "Client Torrent";
            };
          }
        ];
      }
    ];
  };
}