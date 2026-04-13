{config, pkgs, ...}:

{
  # On active le module magique Immich
  services.immich = {
  enable = true;

  # Le port par défaut d'Immich
  port = 2283; 
  host = "127.0.0.1";

  # Le dossier où tes photos seront stockées
  mediaLocation = "/var/lib/immich"; 

  # (Optionnel) Pour utiliser l'accélération matérielle de ton i5 Intel pour l'IA
  machine-learning.enable = true;
  };

  services.paperless = {
      enable = true;
      address = "127.0.0.1";
      port = 28981; # Le port par défaut
      
      settings = {
      # Important pour la sécurité et que l'interface s'affiche bien
      PAPERLESS_URL = "https://paperless.jarvis-edith-ben.duckdns.org";
      
      # On force le moteur OCR (lecture du texte) en français par défaut
      PAPERLESS_OCR_LANGUAGE = "fra"; 
      
      # Le fuseau horaire pour les dates des documents
      PAPERLESS_TIME_ZONE = "Europe/Paris";
      PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
      };
  };

  services.syncthing = {
    enable = true;
    
    # On utilise le standard absolu : le dossier système géré par NixOS
    dataDir = "/var/lib/syncthing"; 
    configDir = "/var/lib/syncthing/.config"; 
    
    guiAddress = "0.0.0.0:8384";
    overrideDevices = true;
    overrideFolders = true;

    settings = {
    devices = {
      "desktop1-nixos" = { id = "IPAQT2V-SLNXYUW-T77SYHC-KDR275S-DPV5QZW-QAPY66E-CXPZ2NG-7GDIJAO"; };
      "laptop1-nixos" = { id = "B6MKGEM-INXUZW7-UILXTAF-6F7C5VX-YUSSK6D-JXK2FIV-OENA7DR-IKIHUAN"; };
    };
    
    folders = {
      "sync" = {               # <-- L'ID COMMUN
        path = "/var/lib/syncthing/sync";        # <-- Chemin spécifique au serveur
        devices = [ "desktop1-nixos" "laptop1-nixos" ];   # Le serveur autorise les deux clients
      };
    };
  };
  };

  systemd.services.filebrowser = {
    description = "Interface Web pour les fichiers de Syncthing";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # Filebrowser pointe directement sur le dossier racine de Syncthing
      ExecStart = "${pkgs.filebrowser}/bin/filebrowser -a 0.0.0.0 -p 8080 -r /var/lib/syncthing/sync -d /var/lib/syncthing/filebrowser.db";
      Restart = "always";
      
      # Très important : Filebrowser utilise le compte 'syncthing' pour éviter les erreurs de droits
      User = "syncthing"; 
    };
  };

  services.adguardhome = {
    enable = true;
    
    # Ouvre automatiquement les ports nécessaires dans le pare-feu NixOS :
    # TCP/UDP 53 (DNS)
    # TCP 3000 (Interface Web)
    openFirewall = true; 
    
    # On préconfigure le port de l'interface Web pour éviter tout conflit avec Caddy
    port = 3000; 
  };

  # On assouplit les règles de sécurité de systemd spécifiquement pour AdGuard
  systemd.services.adguardhome.serviceConfig = {
    # On autorise les "Raw Sockets" (AF_PACKET) vitaux pour le protocole DHCP
    RestrictAddressFamilies = pkgs.lib.mkForce [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_PACKET" "AF_NETLINK" ];
    
    # On lui donne la "Capacité" Linux de forger des paquets réseau
    AmbientCapabilities = pkgs.lib.mkForce [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
    CapabilityBoundingSet = pkgs.lib.mkForce [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
  };

  services.scrutiny = {
    enable = true;
    collector.enable = true;
    settings = {
      web = {
        listen = {
          address = "0.0.0.0";
          port = 8085; # Remplace par le port que tu préfères (ex: 8085)
        };
      };
    };
  };

  systemd.services.scrutiny-collector = {
    serviceConfig = {
      User = "root";
      Group = "root";
    };
  };

  services.actual = {
  enable = true;
  settings = {
    port = 5006;
  };
};

}