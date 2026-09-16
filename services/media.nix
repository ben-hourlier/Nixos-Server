{ config, pkgs, lib, ... }:

{
  # --- Options ---

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

  systemd.services.radarr = {
    serviceConfig = {
      UMask = lib.mkForce "0002";
    };
  };

  systemd.services.sonarr = {
    serviceConfig = {
      UMask = lib.mkForce "0002";
    };
  };

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
      "ratio-limit" = 0; 
      download-dir = "/var/lib/media/downloads";
      incomplete-dir = "/var/lib/media/.incomplete";
      rpc-bind-address = "0.0.0.0";
      rpc-whitelist-enabled = false;
      umask = 2;
    };
  };


  # --- User interface ---  

  services.jellyfin.enable = true;
  users.users.jellyfin.extraGroups = [ "media" "render" "video" ];

  services.seerr.enable = true;
}
