{ config, lib, ... }:

# One registry for everything the server exposes (see services/sites.nix).
# Each site generates, from a single declaration:
#   - its Caddy virtual host (reverse proxy), restricted to the tailnet when
#     `vpn = true`;
#   - for `vpn` sites, a Headscale DNS record pointing the domain to the
#     server's tailnet IP, so tailnet clients reach it through the tunnel;
#   - its Homepage card.
# Each app instance (homelab.apps) also declares the instance itself in the
# app's own NixOS module (services.<service>.instances.<name>.port).

let
  cfg = config.homelab;
  inherit (lib) mkOption types;

  capitalize = s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (-1) s;

  siteModule = { name, config, ... }: {
    options = {
      id = mkOption {
        type = types.str;
        default = name;
        readOnly = true;
        internal = true;
        description = "The site's attribute name, for the code that only gets its value.";
      };
      title = mkOption {
        type = types.str;
        default = name;
        description = "Name shown on the Homepage card.";
      };
      group = mkOption {
        type = types.str;
        default = "Apps";
        description = "Homepage group the card belongs to.";
      };
      icon = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Homepage icon (file from dashboard-icons, `mdi-…` or `si-…`).";
      };
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      domain = mkOption {
        type = types.nullOr types.str;
        default = "${name}.${cfg.domain}";
        defaultText = lib.literalExpression ''"<name>.''${homelab.domain}"'';
        description = "Public domain; null for a card without reverse proxy (LAN link, status widget).";
      };
      port = mkOption {
        type = types.nullOr types.port;
        default = null;
        description = "Local port Caddy proxies to; without it, no virtual host is generated.";
      };
      vpn = mkOption {
        type = types.bool;
        default = false;
        description = "Only reachable from the tailnet and the LAN; other clients are dropped.";
      };
      caddy = mkOption {
        type = types.lines;
        default = "";
        description = "Extra Caddyfile directives for the virtual host (auth, body size…).";
      };
      href = mkOption {
        type = types.nullOr types.str;
        default = if config.domain != null then "https://${config.domain}" else null;
        defaultText = lib.literalExpression ''"https://''${domain}"'';
      };
      ping = mkOption {
        type = types.nullOr types.str;
        default = if config.port != null then "http://127.0.0.1:${toString config.port}" else null;
        defaultText = lib.literalExpression ''"http://127.0.0.1:''${port}"'';
        description = "URL Homepage checks to show the service up or down.";
      };
      widget = mkOption {
        type = types.nullOr (types.attrsOf types.anything);
        default = null;
        description = "Homepage widget, as in Homepage's services.yaml.";
      };
      dashboard = mkOption {
        type = types.bool;
        default = true;
        description = "Show a card on Homepage.";
      };
      usage = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Track when the site was last used (a write request in its Caddy log, see
          services/health.nix) and show it on its card.
        '';
      };
    };
  };

  instanceModule = {
    options = {
      port = mkOption { type = types.port; };
      vpn = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  appModule = { name, ... }: {
    options = {
      service = mkOption {
        type = types.str;
        default = name;
        description = "Name of the app's NixOS module (services.<service>.instances).";
      };
      title = mkOption {
        type = types.str;
        default = capitalize name;
      };
      icon = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      iconPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/icons/icon.svg";
        description = ''
          Path of the icon the app serves itself, loaded from the owner's instance
          (the browser fetches it, from the LAN or the tailnet like Homepage). Wins over icon.
        '';
      };
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      instances = mkOption {
        type = types.attrsOf (types.submodule instanceModule);
        default = { };
        description = ''
          One line per instance. The owner's instance is served at <app>.<domain>
          and listed under "Apps"; the others at <instance>.<app>.<domain>, under "Shared".
        '';
      };
    };
  };

  # Sites generated from the app instances.
  appSites = lib.concatMapAttrs (appName: app:
    lib.mapAttrs' (instName: inst:
      let owned = instName == cfg.owner; in
      lib.nameValuePair "${appName}-${instName}" {
        title = if owned then app.title else "${app.title} · ${capitalize instName}";
        group = if owned then "Apps" else "Shared";
        icon = if app.iconPath != null then "https://${appName}.${cfg.domain}${app.iconPath}" else app.icon;
        inherit (app) description;
        domain = if owned then "${appName}.${cfg.domain}" else "${instName}.${appName}.${cfg.domain}";
        inherit (inst) port vpn;
        # Last use is only worth watching for the others' instances (can it be deleted?).
        usage = !owned;
      }
    ) app.instances
  ) cfg.apps;

  sites = lib.attrValues cfg.sites;
  proxied = lib.filter (s: s.domain != null && s.port != null) sites;
  vpnSites = lib.filter (s: s.vpn) proxied;

  # Matcher shared by every vpn site: the tailnet only (Headscale's v4 and v6 ranges).
  # The LAN is not trusted (guests' devices): at home too, these sites go through
  # the VPN, which the tailnet DNS makes direct on the LAN anyway.
  vpnGuard = ''
    @outside not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48
    abort @outside
  '';

  # Written by services/health.nix, one entry per site with usage = true.
  usageWidget = s: {
    type = "customapi";
    url = "http://localhost:8081/usage.json";
    refreshInterval = 60000;
    mappings = [ { field = s.id; label = "Last use"; } ];
  };

  # A vpn site says so under its name.
  card = s: {
    ${s.title} = lib.filterAttrs (_: v: v != null && v != "") {
      inherit (s) icon href ping;
      widget = if s.widget == null && s.usage then usageWidget s else s.widget;
      description = lib.concatStringsSep " · "
        (lib.filter (d: d != null) [ s.description (if s.vpn then "VPN only" else null) ]);
    };
  };

  # Homepage: one invisible group per row of cfg.rows (groups not listed get a last row),
  # holding that row's groups side by side; cards sorted by title, empty groups left out.
  shown = lib.filter (s: s.dashboard) sites;
  groupCards = g: map card (lib.sort (a: b: a.title < b.title) (lib.filter (s: s.group == g) shown));
  listed = lib.concatLists cfg.rows;
  unlisted = lib.filter (g: !(lib.elem g listed)) (lib.unique (map (s: s.group) shown));
  rows = lib.filter (row: row != [ ])
    (map (lib.filter (g: groupCards g != [ ])) (cfg.rows ++ [ unlisted ]));
  # Homepage orders groups by the layout's keys, which Nix sorts: fine up to 9 rows.
  rowName = i: "row-${toString i}";
in
{
  options.homelab = {
    domain = mkOption {
      type = types.str;
      description = "Base domain of the public sites.";
    };
    owner = mkOption {
      type = types.str;
      description = "Instance name of the server's owner.";
    };
    tailnetIP = mkOption {
      type = types.str;
      description = "The server's IP on the tailnet, which vpn domains resolve to for tailnet clients.";
    };
    rows = mkOption {
      type = types.listOf (types.listOf types.str);
      default = [ ];
      example = [ [ "Infrastructure" "Utilities" "Media" ] [ "Apps" "Shared" ] ];
      description = "Homepage layout: the groups of each row, left to right; groups not listed get a last row.";
    };
    sites = mkOption {
      type = types.attrsOf (types.submodule siteModule);
      default = { };
    };
    apps = mkOption {
      type = types.attrsOf (types.submodule appModule);
      default = { };
    };
  };

  config = {
    homelab.sites = appSites;

    services = lib.mkMerge [
      (lib.mapAttrs' (_: app: lib.nameValuePair app.service {
        enable = true;
        instances = lib.mapAttrs (_: inst: { inherit (inst) port; }) app.instances;
      }) (lib.filterAttrs (_: app: app.instances != { }) cfg.apps))

      {
        caddy.virtualHosts = lib.listToAttrs (map (s: lib.nameValuePair s.domain {
          extraConfig = lib.concatStrings [
            (lib.optionalString s.vpn vpnGuard)
            s.caddy
            "reverse_proxy localhost:${toString s.port}\n"
          ];
        }) proxied);

        headscale.settings.dns.extra_records = map (s: {
          name = s.domain;
          type = "A";
          value = cfg.tailnetIP;
        }) vpnSites;

        homepage-dashboard = {
          services = lib.imap1 (i: row: {
            ${rowName i} = map (g: { ${g} = groupCards g; }) row;
          }) rows;
          settings.layout = lib.listToAttrs (lib.imap1 (i: row: lib.nameValuePair (rowName i) {
            header = false;
            style = "row";
            columns = builtins.length row;
          }) rows);
        };
      }
    ];
  };
}
