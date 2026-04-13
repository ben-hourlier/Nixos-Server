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
        nameservers.global = [ "192.168.42.200" "https://vpn.jarvis-edith-ben.duckdns.org" ]; 
        magic_dns = true;
      };
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts = {

      "jarvis-edith-ben.duckdns.org" = {
        extraConfig = "reverse_proxy localhost:8096";
      };

      "budget.jarvis-edith-ben.duckdns.org" = {
        extraConfig = "reverse_proxy localhost:5006";
      };

      "immich.jarvis-edith-ben.duckdns.org" = {
        extraConfig = "reverse_proxy localhost:2283";
      };

      "paperless.jarvis-edith-ben.duckdns.org" = {
        extraConfig = "reverse_proxy localhost:28981";
      };

      "seerr.jarvis-edith-ben.duckdns.org" = {
        extraConfig = "reverse_proxy localhost:5055";
      };

      "vault.jarvis-edith-ben.duckdns.org" = {
        extraConfig = "reverse_proxy localhost:8222";
      };

      "vpn.jarvis-edith-ben.duckdns.org" = {
        extraConfig = "reverse_proxy localhost:9080";
      };

      "http://localhost:8081" = {
        extraConfig = ''
          root * /var/www/homepage
          file_server
          header Access-Control-Allow-Origin "*"
        '';
      };
      
    };
  };
}
