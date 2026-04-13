{ config, pkgs, ... }:

{
  # 1. Création du groupe commun
  users.groups.media = { gid = 1500; }; # Un GID fixe pour la cohérence

  # 2. Configuration de Transmission (Le client de téléchargement)
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

  # 3. La suite Arr
  services.sonarr = { enable = true; group = "media"; };
  services.radarr = { enable = true; group = "media"; };
  services.prowlarr.enable = true;
  services.flaresolverr = {
    enable = true;
    port = 8191;
  };
  services.bazarr = {
    enable = true;
    group = "media";
  };

  # Le serveur multimédia
  services.jellyfin.enable = true;
  
  # On ajoute l'utilisateur jellyfin à notre groupe "media" magique
  users.users.jellyfin.extraGroups = [ "media" "render" "video" ];

  # 4. L'interface de requête (Overseerr)
  services.seerr.enable = true; # Port 5055 par défaut

  # 5. Création des répertoires avec les bonnes permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/media 2775 root media -"
    "d /var/lib/media/downloads 2775 root media -"
    "d /var/lib/media/.incomplete 2775 root media -"
    "d /var/lib/media/movies 2775 root media -"
    "d /var/lib/media/shows 2775 root media -"
  ];


  systemd.services.media-cleanup = {
    description = "Nettoyage automatique Radarr/Sonarr si disque plein";
    serviceConfig = {
      Type = "oneshot";
      User = "ben";
      ExecStart = "/etc/nixos/scripts/cleanup-media.sh";
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
