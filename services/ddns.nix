{ config, pkgs, ... }:

{
  services.ddclient = {
    enable = true;
    protocol = "duckdns";
    domains = [ "jarvis-edith-ben" ]; # Ton domaine, sans le .duckdns.org
    
    # DuckDNS n'utilise pas de nom d'utilisateur, mais ddclient a parfois 
    # besoin que le champ ne soit pas vide pour fonctionner.
    username = "na"; 
    
    # On pointe vers le fichier sécurisé que tu as déjà créé !
    passwordFile = "/var/lib/duckdns/token";
  };
}
