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
      PAPERLESS_URL = "https://paperless.bhr-sys.com";
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
        "desktop1-nixos" = { id = "DBFJJQQ-A2EOXSZ-MLGN7ZX-YC7BIQC-F4BE746-P5X73OV-3FT7HMC-NXS6BAS"; };
        "laptop1-nixos" = { id = "UWV3TFY-GIWW3T5-VRTLB25-XDDUT36-64PK4FG-LTVKPMS-TEROAPL-XLAUZAO"; };
      };
    
      folders = {
        "Sync" = {
          path = "/var/lib/syncthing/Sync";
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
      ExecStart = "${pkgs.filebrowser}/bin/filebrowser -a 0.0.0.0 -p 8080 -r /var/lib/syncthing/Sync -d /var/lib/syncthing/filebrowser.db";
      Restart = "always";
      User = "syncthing"; 
    };
  };

  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
      DOMAIN = "https://vault.bhr-sys.com";
    };
  };

  services.actual = {
    enable = true;
    settings = {
      port = 5006;
    };
  };

  services.focus = {
    enable = true;
    instances = {
      ben = {
        port = 8765;
      };

      nina = {
        port = 8766;
      };

      raph = {
        port = 8767;
      };

      kilian = {
        port = 8768;
      };
    };
  };

  services.getdone = {
    enable = true;
    instances = {
      ben = {
        port = 9870;
        host = "127.0.0.1";
      };

      nina = {
        port = 9871;
        host = "127.0.0.1";
      };

      oscar = {
        port = 9872;
        host = "127.0.0.1";
      };

      kilian = {
        port = 9873;
        host = "127.0.0.1";
      };
    };
  };

}