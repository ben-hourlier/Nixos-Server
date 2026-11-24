{config, pkgs, ...}:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    allowedHosts = "192.168.42.200:8082,100.64.0.2:8082";

    widgets = [
      {
        greeting = {
          text_size = "xl";
          text = "Server1-NixOS";
        };
      }
      {
        resources = {
          cpu = true;
          units = "metric";
          cputemp = true;
          tempmin = 0;
          tempmax = 100;
          memory = true;
          disk = [ "/" "/mnt/disk1" ];
        };
      }
    ];

    # Service cards are generated from services/sites.nix.
  };
}
