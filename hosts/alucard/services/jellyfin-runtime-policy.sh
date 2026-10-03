#!/usr/bin/env bash
set -euo pipefail

data_dir="${JELLYFIN_DATA_DIR%/}"
owner="$JELLYFIN_USER:$JELLYFIN_GROUP"

network_config="$data_dir/config/network.xml"
test -f "$network_config"

current_addresses="$(xml sel -t -v 'count(/NetworkConfiguration/LocalNetworkAddresses/string[text() = "127.0.0.1"])' "$network_config")"
current_ipv6="$(xml sel -t -v '/NetworkConfiguration/EnableIPv6' "$network_config")"
if [ "$current_addresses" != 1 ] || [ "$current_ipv6" != false ]; then
  xml ed -P -L \
    -d '/NetworkConfiguration/LocalNetworkAddresses/*' \
    -s '/NetworkConfiguration/LocalNetworkAddresses' -t elem -n string -v 127.0.0.1 \
    -u '/NetworkConfiguration/EnableIPv6' -v false \
    "$network_config"
  chown "$owner" "$network_config"
fi

sso_config="$data_dir/plugins/configurations/SSO-Auth.xml"
if [ -f "$sso_config" ]; then
  provider="/PluginConfiguration/OidConfigs/item[key/string = 'keycloak']/value/PluginConfiguration"
  provider_count="$(xml sel -t -v "count($provider)" "$sso_config")"
  if [ "$provider_count" = 1 ]; then
    setting_count="$(xml sel -t -v "count($provider/DisablePushedAuthorization)" "$sso_config")"
    if [ "$setting_count" = 0 ]; then
      xml ed -P -L \
        -s "$provider" -t elem -n DisablePushedAuthorization -v true \
        "$sso_config"
      chown "$owner" "$sso_config"
    elif [ "$setting_count" = 1 ] \
      && [ "$(xml sel -t -v "$provider/DisablePushedAuthorization" "$sso_config")" != true ]; then
      xml ed -P -L \
        -u "$provider/DisablePushedAuthorization" -v true \
        "$sso_config"
      chown "$owner" "$sso_config"
    elif [ "$setting_count" != 1 ]; then
      echo "expected at most one DisablePushedAuthorization setting for the keycloak provider" >&2
      exit 1
    fi
  elif [ "$provider_count" != 0 ]; then
    echo "expected at most one keycloak OIDC provider" >&2
    exit 1
  fi
fi
