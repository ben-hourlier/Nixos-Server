{config, pkgs, ...}:

let
  porkbunDdnsScript = pkgs.writeShellApplication {
    name = "porkbun-ddns";
    runtimeInputs = with pkgs; [ curl jq coreutils ];
    text = ''
      set -euo pipefail

      DOMAIN="bhr-sys.com"
      CACHE_FILE="/var/lib/porkbun-ddns/last_ip"
      mkdir -p "$(dirname "$CACHE_FILE")"

      # 1. Fetch current public IP detected by Porkbun
      PING_PAYLOAD=$(jq -n \
        --arg k "$PORKBUN_API_KEY" \
        --arg s "$PORKBUN_SECRET_KEY" \
        '{"apikey": $k, "secretapikey": $s}')

      PING_RESPONSE=$(curl -s -X POST "https://api.porkbun.com/api/json/v3/ping" \
        -H "Content-Type: application/json" \
        -d "$PING_PAYLOAD")

      STATUS=$(echo "$PING_RESPONSE" | jq -r '.status // empty')
      if [ "$STATUS" != "SUCCESS" ]; then
        echo "Porkbun API authentication error: $PING_RESPONSE" >&2
        exit 1
      fi

      CURRENT_IP=$(echo "$PING_RESPONSE" | jq -r '.yourIp')

      # 2. Skip update if public IP did not change
      if [ -f "$CACHE_FILE" ] && [ "$(cat "$CACHE_FILE")" = "$CURRENT_IP" ]; then
        echo "Public IP unchanged ($CURRENT_IP). Skipping update."
        exit 0
      fi

      echo "Public IP changed to $CURRENT_IP. Updating Porkbun DNS..."

      # 3. Update wildcard record (*) safely with jq
      UPDATE_PAYLOAD=$(jq -n \
        --arg k "$PORKBUN_API_KEY" \
        --arg s "$PORKBUN_SECRET_KEY" \
        --arg ip "$CURRENT_IP" \
        '{"apikey": $k, "secretapikey": $s, "content": $ip, "ttl": "600"}')

      ENDPOINT="https://api.porkbun.com/api/json/v3/dns/editByNameType/$DOMAIN/A/*"
      RESPONSE=$(curl -s -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$UPDATE_PAYLOAD")

      SUB_STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')
      if [ "$SUB_STATUS" != "SUCCESS" ]; then
        echo "Failed to update wildcard record: $RESPONSE" >&2
        exit 1
      fi

      echo "$CURRENT_IP" > "$CACHE_FILE"
      echo "Successfully updated *.$DOMAIN to $CURRENT_IP."
    '';
  };
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/porkbun-ddns 0750 root root -"
  ];

  systemd.services.porkbun-ddns = {
    description = "Porkbun Dynamic DNS Update";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      EnvironmentFile = config.sops.secrets.porkbun.path;
      ExecStart = "${porkbunDdnsScript}/bin/porkbun-ddns";
    };
  };

  systemd.timers.porkbun-ddns = {
    description = "Porkbun Dynamic DNS Update Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "10min";
      Persistent = true;
    };
  };


  # --- AdGuard ---

  # Disabled because too slow.

  # services.adguardhome = {
  #   enable = true;
  #   openFirewall = true;
  #   port = 3000; 
  # };
}