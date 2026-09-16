{ config, pkgs, ... }:

{
  # ====================================================================
  # --- Config & Firewall ---
  # ====================================================================

  # --- Options & Fix address ---

  networking.networkmanager.enable = true;

  networking.interfaces."eno1".ipv4.addresses = [{
    address = "192.168.42.200";
    prefixLength = 24;
  }];

  # networking.useDHCP = false;
  # networking.interfaces.eno1.useDHCP = false;

  # Optimize performances for streaming,VPN and server access.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", NAME=="eno1", RUN+="${pkgs.ethtool}/bin/ethtool -K eno1 rx-udp-gro-forwarding on rx-gro-list off"
  '';
  

  # --- Router, DNS, NAT ---

  # equivalent to : iptables -t nat -A POSTROUTING -i tailscale0 -o eno1 -j MASQUERADE
  networking.nat = {
    enable = true;
    externalInterface = "eno1"; 
    internalInterfaces = [ "tailscale0" ];
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking.defaultGateway = "192.168.42.1";
  networking.nameservers = [ "127.0.0.1" ];
  networking.networkmanager.dns = "none";

  
  # --- Firewall ---

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose";

    allowedTCPPorts = [ 
      80 443 53 # HTTP(S) & DNS
      5055 6767 7878 8096 8989 9091 9696 # Media
      2283 # Immich
      3001 # AdGuard
      5006 # Actual Budget
      8080 # FileBrowser
      8081 # Media Cleaner / local file server
      8082 # Homepage
      8085 # Scrutiny
      8384 # Syncthing
      9080 # Headscale
      28981 # Paperless
    ];

    allowedUDPPorts = [ 
      53 # DNS
      67 # DHCP server (68 for client)
      21027 # Syncthing search for local devices
      51820 # Wireguard
    ];
  };


  # ====================================================================
  # --- VPN ---
  # ====================================================================

  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 9080;
    settings = {
      server_url = "https://vpn.bhr-sys.com"; 
      dns = {
        nameservers.global = [ "192.168.42.200" ];
        base_domain = "headscale.net"; # Suffix for devices name MagicDNS
        magic_dns = true; # Use devices name as "DNS"
      };
    };
  };

  services.tailscale.enable = true;


  # ====================================================================
  # --- Reverse Proxy ---
  # ====================================================================

  services.caddy = {
    enable = true;
    virtualHosts = {

      "budget.bhr-sys.com" = {
        extraConfig = "reverse_proxy localhost:5006";
      };

      "files.bhr-sys.com" = {
        extraConfig = "reverse_proxy localhost:8080";
      };

      "immich.bhr-sys.com" = {
        extraConfig = "reverse_proxy localhost:2283";
      };

      "jellyfin.bhr-sys.com" = {
        extraConfig = "reverse_proxy localhost:8096";
      };

      "ntfy.bhr-sys.com" = {
        extraConfig = "reverse_proxy localhost:2586";
      };

      "paperless.bhr-sys.com" = {
        extraConfig = "reverse_proxy localhost:28981";
      };

      "seerr.bhr-sys.com" = {
        extraConfig = "reverse_proxy localhost:5055";
      };

      "vault.bhr-sys.com" = {
        extraConfig = "reverse_proxy localhost:8222";
      };

      "vpn.bhr-sys.com" = {
        extraConfig = "reverse_proxy localhost:9080";
      };

      ":8081" = {
        # Caddyfile language injection
        # "root *" define root folder for all requests
        # activate file_server mode (html, css, images)
        # allows requests from all origin (required for Kopia API)
        extraConfig = ''
          root * /var/www/homepage
          file_server
          header Access-Control-Allow-Origin "*"
        '';
      };

      # Test for maintenance page
      "test.bhr-sys.com" = {
        extraConfig = ''
          root * /var/www/maintenance
          error 503

          handle_errors {
            rewrite * /maintenance.html
            file_server
          }
        '';
      };
    };
  };

  # Dans ta configuration NixOS (ex: server-configuration.nix)
  systemd.tmpfiles.rules = [
    "d /var/www/maintenance 0755 caddy caddy -"
    "f /var/www/maintenance/maintenance.html 0644 caddy caddy - <html><body><h1>Serveur en maintenance</h1><p>Nous revenons vite !</p></body></html>"
  ];
}
