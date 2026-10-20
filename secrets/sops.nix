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