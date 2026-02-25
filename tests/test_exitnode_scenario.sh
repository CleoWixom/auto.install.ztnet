#!/usr/bin/env bash
set -euo pipefail

SCRIPT="ztnet.sh"
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT

FAKEBIN="$TMPROOT/fakebin"
mkdir -p "$FAKEBIN"

cat > "$FAKEBIN/curl" <<'CURL_EOF'
#!/usr/bin/env bash
set -euo pipefail
method="GET"
url=""
write_fmt=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -X)
      method="$2"
      shift 2
      ;;
    -w)
      write_fmt="$2"
      shift 2
      ;;
    -o|-H|-d)
      shift 2
      ;;
    -s)
      shift
      ;;
    http://*|https://*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "$url" == *"/api/healthcheck"* ]]; then
  [ -n "$write_fmt" ] && printf '200'
  exit 0
fi

if [[ "$method" == "POST" && "$url" == *"/api/v1/user" ]]; then
  printf '{"apiToken":"tok123"}'
  exit 0
fi

if [[ "$method" == "POST" && "$url" == *"/api/v1/network" ]]; then
  printf '{"id":"abcdef1234567890"}'
  exit 0
fi

if [[ "$method" == "PUT" && "$url" == *"/api/v1/network/abcdef1234567890" ]]; then
  printf '{"ok":true}'
  exit 0
fi

if [[ "$method" == "GET" && "$url" == *"/member/a1b2c3d4e5" ]]; then
  printf '{"id":"a1b2c3d4e5"}'
  exit 0
fi

if [[ "$method" == "POST" && "$url" == *"/member/a1b2c3d4e5" ]]; then
  printf '{"authorized":true}'
  exit 0
fi

printf '{}'
CURL_EOF
chmod +x "$FAKEBIN/curl"

cat > "$FAKEBIN/zerotier-cli" <<'ZT_EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  status|join|set) exit 0 ;;
  info) echo "200 info a1b2c3d4e5 1.14.2 ONLINE"; exit 0 ;;
  *) exit 0 ;;
esac
ZT_EOF
chmod +x "$FAKEBIN/zerotier-cli"

cat > "$FAKEBIN/ip" <<'IP_EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == "link show" ]]; then
  echo "2: ztabc: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 2800 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000"
  exit 0
fi

if [[ "${1:-}" == "addr" && "${2:-}" == "show" ]]; then
  cat <<OUT
3: ztabc: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 2800
    inet 192.168.55.1/24 brd 192.168.55.255 scope global ztabc
OUT
  exit 0
fi

exit 0
IP_EOF
chmod +x "$FAKEBIN/ip"

export PATH="$FAKEBIN:$PATH"

server_ip="http://127.0.0.1"
GREEN=""
RED=""
YELLOW=""
NC=""
STD="verbose"
verbose() { "$@"; }
print_status() { :; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

awk 'f{print} /^# ===========================================================================$/{if (seen==0){seen=1;f=1;print}}' "$SCRIPT" \
  | sed "s|/etc/ztnet|$TMPROOT/etc_ztnet|g" \
  | sed -E '/^exitnode_[a-z0-9_]+[[:space:]]*$/d' > "$TMPROOT/exitnode_section.sh"

# shellcheck disable=SC1090
source "$TMPROOT/exitnode_section.sh"

exitnode_wait_api
exitnode_create_admin
[ "$(cat "$API_TOKEN_FILE")" = "tok123" ]

exitnode_create_network
[ "$(cat "$NETWORK_ID_FILE")" = "abcdef1234567890" ]

exitnode_configure_network
exitnode_join_network
[ "$NODE_ID" = "a1b2c3d4e5" ]
[ "$ZT_INTERFACE" = "ztabc" ]

exitnode_authorize
[ -n "$SIXPLANE_IP" ]

echo "Simulated ExitNode scenario passed."
