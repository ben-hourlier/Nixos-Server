{ config, lib, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix

      ./services/backup.nix
      ./services/dashboard.nix
      ./services/ddns.nix
      ./services/immich.nix
      ./services/media.nix
      ./services/reverse_proxy.nix
      ./services/vaultwarden.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.nix-ld.enable = true;

  programs.fuse.userAllowOther = true;

  powerManagement.cpuFreqGovernor = "powersave";
  services.fstrim.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # Pour les processeurs récents (Broadwell et +)
      intel-compute-runtime # Ajoute ceci (OpenCL/QSV support)
      vpl-gpu-rt
      intel-vaapi-driver # Pour les anciens modèles
    ];
  };


  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
  };


  hardware.enableRedistributableFirmware = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "server1-nixos"; 

  networking.networkmanager.enable = true;

  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = false;

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking.interfaces."eno1".ipv4.addresses = [{
    address = "192.168.42.200"; # L'adresse IP actuelle de ton serveur
    prefixLength = 24;        # Cela correspond au masque 255.255.255.0
  }];

  networking.nat = {
    enable = true;
    # REMPLACE "eno1" par le vrai nom de l'interface réseau physique de ton serveur (ex: eth0, enp3s0...)
    externalInterface = "eno1"; 
    internalInterfaces = [ "tailscale0" ];
  };

  networking.defaultGateway = "192.168.42.1";
  networking.nameservers = [ "127.0.0.1" ];
  networking.networkmanager.dns = "none";

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose";
    extraCommands = ''
      iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    '';

    allowedTCPPorts = [ 
      80   # HTTP (pour que Caddy puisse prouver à Let's Encrypt qui il est)
      443  # HTTPS (le port sécurisé pour tes amis)
      5055
      6246
      6767
      7878
      8096
      8989
      9091

      2283
      28981

      8080
      8384
      22000
      21027

      67
      68
      53

      8082
      8222
      5006

      8085
      3001
    ];

    allowedUDPPorts = [ 
      80   # HTTP (pour que Caddy puisse prouver à Let's Encrypt qui il est)
      443  # HTTPS (le port sécurisé pour tes amis)
      5055
      6246
      6767
      7878
      8096
      8989

      2283
      28981

      8080
      8384
      22000
      21027

      67
      68
      53
      
      51820
      8222
    ];
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", NAME=="eno1", RUN+="${pkgs.ethtool}/bin/ethtool -K eno1 rx-udp-gro-forwarding on rx-gro-list off"
  '';

  services.tailscale.enable = true;

  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";

  services.xserver.xkb.layout = "fr";

  users.users.ben = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO8w0K1NT6NTmJd3mWJFCJ94zyWJaEkXGRJNCYOKyblG NixOs"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM66hTYZVuVKYEHQjebXBpKmgsHqSZF9fHBDs9r4igY+ laptop1"
    ];
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    jq
    neovim 
    wget
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  system.stateVersion = "25.11"; 

  fileSystems."/mnt/disk1" = {
    device = "/dev/disk/by-uuid/5acaa5dd-a82b-4021-baad-629ef73c692c"; 
    options = [ 
      "users"     # Allows normal users to interact with the drive without sudo.
      "nofail"    # CRITICAL: Prevents a kernel panic if the drive is disconnected during boot.
      "noatime"   # Disables writing access times to the disk, prolonging its lifespan and speeding up reads.
    ];
  };

}

