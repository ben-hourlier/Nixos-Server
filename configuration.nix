{ config, lib, pkgs, ... }:

{
  # ====================================================================
  # --- Core System ---
  # ====================================================================

  imports = [ 
    ./hardware-configuration.nix

    ./services/backup.nix
    ./services/dashboard.nix
    ./services/infrastructure.nix
    ./services/media.nix
    ./services/network.nix
    ./services/utilities.nix
  ];

  # --- NixOS Configuration ---

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  hardware.enableRedistributableFirmware = true;
  programs.nix-ld.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "server1-nixos";
  system.stateVersion = "25.11"; 

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime
      intel-media-driver
      intel-vaapi-driver
      vpl-gpu-rt
    ];
  };

  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # --- Time & Locales ---

  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";

  services.xserver.xkb.layout = "fr";  


  # ====================================================================
  # --- File system & Hardware Optimization ---
  # ====================================================================

  powerManagement.cpuFreqGovernor = "powersave";
  services.fstrim.enable = true;

  fileSystems."/".options = [ "noatime" ];

  fileSystems."/mnt/disk1" = {
    device = "/dev/disk/by-uuid/5acaa5dd-a82b-4021-baad-629ef73c692c"; 
    options = [ 
      "users"     
      "nofail"
      "noatime"
    ];
  };

  # 120 = 10 min inactivty before stopping disk (legacy from old complex time attribution)
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="5acaa5dd-a82b-4021-baad-629ef73c692c", RUN+="${pkgs.hdparm}/bin/hdparm -S 120 /dev/disk/by-uuid/5acaa5dd-a82b-4021-baad-629ef73c692c"
  '';

  # Limitation of the logs to limit writing
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=1month
  '';


  # ====================================================================
  # --- User & Programs ---
  # ====================================================================

  users.users.ben = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO8w0K1NT6NTmJd3mWJFCJ94zyWJaEkXGRJNCYOKyblG NixOs"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM66hTYZVuVKYEHQjebXBpKmgsHqSZF9fHBDs9r4igY+ laptop1"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    jq
    kopia
    neovim 
    wget
  ];
}