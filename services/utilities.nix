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

  systemd.services.filebrowser = let
    config-file = pkgs.writeText "filebrowser-quantum.yaml" ''
      server:
        port: 8080
        database: /var/lib/syncthing/filebrowser-quantum.db
        cacheDir: /var/cache/filebrowser
        sources:
          - path: /var/lib/syncthing/Sync
            name: Sync
            config:
              defaultEnabled: true
      auth:
        adminUsername: ben
    '';
  in {
    description = "Web interface for syncthing (FileBrowser Quantum)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.ffmpeg-headless ]; # video thumbnails and HEIC previews
    serviceConfig = {
      ExecStart = "${pkgs.filebrowser-quantum}/bin/filebrowser-quantum -c ${config-file}";
      EnvironmentFile = config.sops.secrets.filebrowser.path; # FILEBROWSER_ADMIN_PASSWORD=...
      CacheDirectory = "filebrowser";
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

  services.calendar = { 
    enable = true; 
    instances.ben.port = 9880; 
  };

  services.inventory = {
    enable = true;
    instances.ben.port = 9900;
  };

  services.webmail = {
    enable = true;
    instances.ben = {
      port = 9890;
      accountsFile = config.sops.templates."webmail-accounts.json".path;
      accounts = {
        perso = { name = "Perso"; address = config.sops.placeholder.mail-perso-address; realName = "Ben";
          passwordFile = config.sops.secrets.mail-perso.path;
          imap.host = "imap.gmail.com"; smtp.host = "smtp.gmail.com"; };
        aen7 = { name = "AEN7"; address = config.sops.placeholder.mail-aen7-address; realName = "Benjamin Hourlier";
          passwordFile = config.sops.secrets.mail-aen7.path;
          imap.host = "imap.gmail.com"; smtp.host = "smtp.gmail.com"; };
        inp = { name = "INP"; address = config.sops.placeholder.mail-inp-address; realName = "Benjamin Hourlier";
          passwordFile = config.sops.secrets.mail-inp.path;
          imap.host = "partage.toulouse-inp.fr";
          smtp = { host = "partage.toulouse-inp.fr"; port = 587; security = "starttls"; };
          folders.archive = "Archive"; };
      };
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

      vic = {
        port = 9874;
        host = "127.0.0.1";
      };
    };
  };

  # --- Dictée: dictated mp3 -> formatted French text ---

  # whisper.cpp on CPU, local only. Same model as the desktop (small, unquantized).
  systemd.services.whisper-server = {
    description = "Whisper.cpp inference server (used by Dictée)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.whisper-cpp}/bin/whisper-server --model ${pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin";
        hash = "sha256-G+OpsgY4Z7k35k4ux0gzZKeZF+FX+pjF2UtcH//qmHs=";
      }} --host 127.0.0.1 --port 8178 --threads 4";
      Restart = "always";
      RestartSec = 3;
      DynamicUser = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  services.dictee = {
    enable = true;
    port = 9910;
    whisperUrl = "http://127.0.0.1:8178";
  };

}