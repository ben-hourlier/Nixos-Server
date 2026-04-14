{config, pkgs, ...}:

{
  services.immich = {
    enable = true;
    port = 2283; 
    host = "127.0.0.1";
    mediaLocation = "/var/lib/immich";
    machine-learning.enable = true;
  };

  services.paperless = {
    enable = true;
    address = "127.0.0.1";
    port = 28981;
    settings = {
      PAPERLESS_URL = "https://paperless.jarvis-edith-ben.duckdns.org";
      PAPERLESS_OCR_LANGUAGE = "fra"; 
      
      PAPERLESS_TIME_ZONE = "Europe/Paris";
      PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
    };
  };

  services.syncthing = {
    enable = true;
    dataDir = "/var/lib/syncthing"; 
    configDir = "/var/lib/syncthing/.config"; 
    guiAddress = "0.0.0.0:8384";

    # Override allows only devices declared in Nix
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      devices = {
        "desktop1-nixos" = { id = "IPAQT2V-SLNXYUW-T77SYHC-KDR275S-DPV5QZW-QAPY66E-CXPZ2NG-7GDIJAO"; };
        "laptop1-nixos" = { id = "B6MKGEM-INXUZW7-UILXTAF-6F7C5VX-YUSSK6D-JXK2FIV-OENA7DR-IKIHUAN"; };
      };
    
      folders = {
        "sync" = {
          path = "/var/lib/syncthing/sync";
          devices = [ "desktop1-nixos" "laptop1-nixos" ];
        };
      };
    };
  };

  systemd.services.filebrowser = {
    description = "Web interface for syncthing";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.filebrowser}/bin/filebrowser -a 0.0.0.0 -p 8080 -r /var/lib/syncthing/sync -d /var/lib/syncthing/filebrowser.db";
      Restart = "always";
      User = "syncthing"; 
    };
  };

  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false; # À passer en false après création du compte !
      # Utilisation de Tailscale pour le domaine
      DOMAIN = "https://vault.jarvis-edith-ben.duckdns.org";
    };
  };

  services.actual = {
  enable = true;
  settings = {
    port = 5006;
  };
};

}