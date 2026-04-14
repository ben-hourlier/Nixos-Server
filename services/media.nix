{ config, pkgs, ... }:
let
  mediaCleanup = import ../scripts/media-cleanup.nix { inherit pkgs; };
in
{
  # --- Options ---

  environment.systemPackages = [
    mediaCleanup
  ];

  users.groups.media = { gid = 1500; };

  systemd.tmpfiles.rules = [
    "d /var/lib/media 2775 root media -"
    "d /var/lib/media/downloads 2775 root media -"
    "d /var/lib/media/.incomplete 2775 root media -"
    "d /var/lib/media/movies 2775 root media -"
    "d /var/lib/media/shows 2775 root media -"
  ];


  # --- Arr Suite ---

  services.sonarr = { enable = true; group = "media"; };
  services.radarr = { enable = true; group = "media"; };
  services.bazarr = { enable = true; group = "media"; };
  services.prowlarr.enable = true;

  services.flaresolverr = {
    enable = true;
    port = 8191;
  };
  

  # --- Download Client ---

  services.transmission = {
    enable = true;
    group = "media";
    openPeerPorts = true;
    settings = {
      "ratio-limit-enabled" = true;
      # On fixe la limite à 0 (Arrêt immédiat après téléchargement)
      "ratio-limit" = 0;
      download-dir = "/var/lib/media/downloads";
      incomplete-dir = "/var/lib/media/.incomplete";
      rpc-bind-address = "0.0.0.0"; # Attention: à protéger par ton Firewall/VPN
      rpc-whitelist-enabled = false;
      umask = 1; # Important: crée les fichiers avec les droits 775 (groupe modifiable)
    };
  };


  # --- User interface ---  

  services.jellyfin.enable = true;
  users.users.jellyfin.extraGroups = [ "media" "render" "video" ];

  services.seerr.enable = true;

  
  # --- Media management ---

  systemd.services.media-cleanup = {
    description = "Media management for Radarr/Sonarr";
    serviceConfig = {
      Type = "oneshot";
      User = "ben";
      ExecStart = "media-cleanup";
    };
  };

  systemd.timers.media-cleanup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
