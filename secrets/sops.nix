{ config, ... }:

{
  sops = {
    defaultSopsFile = ./secret.yaml;
    defaultSopsFormat = "yaml";

    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      kopia = {
        owner = "root";
        mode = "0400";
      };
      porkbun = {
        owner = "root";
        mode = "0400";
      };
      radarr = {
        owner = "root";
        mode = "0400";
      };
      sonarr = {
        owner = "root";
        mode = "0400";
      };
      mail-perso = {
        owner = "root";
        mode = "0400";
      };
      mail-aen7 = {
        owner = "root";
        mode = "0400";
      };
      mail-inp = {
        owner = "root";
        mode = "0400";
      };
      mail-perso-address = {
        owner = "root";
        mode = "0400";
      };
      mail-aen7-address = {
        owner = "root";
        mode = "0400";
      };
      mail-inp-address = {
        owner = "root";
        mode = "0400";
      };
    };

    # Webmail accounts with the real addresses, kept out of the store and of the repo.
    templates."webmail-accounts.json" = {
      content = config.services.webmail.instances.ben.accountsJSON;
      restartUnits = [ "webmail-ben.service" ];
    };

    templates."arr-env" = {
      content = ''
        HOMEPAGE_VAR_SONARR_API=${config.sops.placeholder.sonarr}
        HOMEPAGE_VAR_RADARR_API=${config.sops.placeholder.radarr}
      '';
    };
  };

  systemd.services.homepage-dashboard.serviceConfig.EnvironmentFile = 
    config.sops.templates."arr-env".path;
}