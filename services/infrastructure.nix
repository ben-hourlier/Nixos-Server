{config, pkgs, ...}:

{ 
  # --- Dynamic DNS ---

  services.ddclient = {
    enable = true;
    protocol = "duckdns";
    domains = [ "jarvis-edith-ben" ];
    username = "na";
    passwordFile = "/var/lib/duckdns/token";
  };


  # --- AdGuard ---

  services.adguardhome = {
    enable = true;
    openFirewall = true;
    port = 3000; 
  };

  # More flexible rules for AdGuard
  systemd.services.adguardhome.serviceConfig = {
    RestrictAddressFamilies = pkgs.lib.mkForce [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_PACKET" "AF_NETLINK" ];
    AmbientCapabilities = pkgs.lib.mkForce [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
    CapabilityBoundingSet = pkgs.lib.mkForce [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
  };


  # --- Scrutiny ---

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
}