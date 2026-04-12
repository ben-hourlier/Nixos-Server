{ config, pkgs, ... }:

{
    
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 9080;
    settings = {
      # REMPLACE par ton vrai domaine DuckDNS
      server_url = "https://vpn.jarvis-edith-ben.duckdns.org"; 
      dns = {
        # On dit au VPN d'utiliser ton AdGuard Home !
        base_domain = "192.168.42.200";
        nameservers.global = [ "192.168.42.200" ]; 
        magic_dns = true;
      };
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts = {

      "budget.jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:5006";
      };

      "jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:8096";
      };

      # L'accès pour Overseerr (le sous-domaine)
      "seerr.jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:5055";
      };

      "immich.jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:2283";
      };

      "paperless.jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:28981";
      };

      "files.jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:8080";
      };

      "vpn.jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:9080";
      };

      "vault.jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:8222";
      };

      "status.jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:3001";
      };

      "dashboard.jarvis-edith-ben.duckdns.org" = {
      extraConfig = "reverse_proxy localhost:8082";
      };
    };
  };
}
