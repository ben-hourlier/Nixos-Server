{ ... }:

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
      media_cleanup = {
        owner = "root";
        mode = "0400";
      };
    };
  };
}