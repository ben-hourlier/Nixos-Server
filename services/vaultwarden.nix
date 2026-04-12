{config, pkgs, ... }:

{
  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false; # À passer en false après création du compte !
      # Utilisation de Tailscale pour le domaine
      DOMAIN = "https://vault.jarvis-edith-ben.duckdns.org";
    };
  };
}