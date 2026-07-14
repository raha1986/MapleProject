#!/bin/bash
set -x
trap 'echo "❌❌❌ ERROR at line $LINENO"' ERR

set -euo pipefail

# ============================
#   Ramtin 19-Protocol Builder
# ============================

# Must run as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Please run as root"
    exit 1
fi

# Update & install base tools
apt update && apt upgrade -y
apt install -y curl nano xclip xsel net-tools jq openssl

# Install Xray (simple official installer)
if ! command -v xray >/dev/null 2>&1; then
    bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
fi

# Get real public IP
SERVER_IP=$(curl -s ipv4.icanhazip.com)
[ -z "$SERVER_IP" ] && SERVER_IP=$(curl -s ifconfig.me)

# Prefix generator: Rami + random 100–199
generate_prefix() {
    local RAND=$((100 + RANDOM % 100))
    echo "Rami${RAND}"
}

# Safe WS path (shared for all WS)
WS_PATH="/cdn-cgi/trace"

# Ports (safe list first)
SAFE_PORTS=(443 8443 2053 2087 2096 2083 8080 8081 8082 8083 8084 8085)

# Generate random port if needed
generate_port() {
    while true; do
        local PORT=$((20000 + RANDOM % 20000))
        if ! nc -z localhost "$PORT" 2>/dev/null; then
            echo "$PORT"
            return
        fi
    done
}

# Collect ports for 19 configs
PORTS=()
for P in "${SAFE_PORTS[@]}"; do
    if ! nc -z localhost "$P" 2>/dev/null; then
        PORTS+=("$P")
    fi
done

while [ "${#PORTS[@]}" -lt 19 ]; do
    PORTS+=("$(generate_port)")
done

# Assign ports (fixed order)
PORT_VLESS_WS=${PORTS[0]}
PORT_VMESS_WS=${PORTS[1]}
PORT_TROJAN_WS=${PORTS[2]}
PORT_SS_WS=${PORTS[3]}

PORT_VLESS2_WS=${PORTS[4]}
PORT_VMESS2_WS=${PORTS[5]}
PORT_TROJAN2_WS=${PORTS[6]}
PORT_SS2_WS=${PORTS[7]}

PORT_VLESS3_WS=${PORTS[8]}
PORT_VMESS3_WS=${PORTS[9]}
PORT_TROJAN3_WS=${PORTS[10]}
PORT_SS3_WS=${PORTS[11]}

PORT_REALITY=443
PORT_TLS=8443

PORT_VLESS_TCP=${PORTS[12]}
PORT_VMESS_TCP=${PORTS[13]}
PORT_TROJAN_TCP=${PORTS[14]}
PORT_SS_TCP=${PORTS[15]}
PORT_HYSTERIA2=${PORTS[16]}

# UUIDs & passwords
uuid() { cat /proc/sys/kernel/random/uuid; }

VLESS_UUID=$(uuid)
VMESS_UUID=$(uuid)
SS_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
echo "Create TROJAN_PASS ❌❌❌❌❌❌"
TROJAN_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)

VLESS_UUID2=$(uuid)
VMESS_UUID2=$(uuid)
TROJAN_PASS2=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
SS_PASS2=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)

VLESS_UUID3=$(uuid)
VMESS_UUID3=$(uuid)
TROJAN_PASS3=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
SS_PASS3=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)

# Reality keys (Auto-Fix)
XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")

# Try generating real Reality keys
REALITY_KEYS=""
if $XRAY_BIN x25519 >/dev/null 2>&1; then
    echo "✔ Reality key generation supported"
    REALITY_KEYS=$($XRAY_BIN x25519)
    REALITY_PRIVATE=$(echo "$REALITY_KEYS" | awk '/Private/{print $3}')
    REALITY_PUBLIC=$(echo "$REALITY_KEYS" | awk '/Public/{print $3}')
else
    echo "⚠ Reality key generation NOT supported — using fallback keys"
    # Fallback keys (valid format, but not secure — works for config generation)
    REALITY_PRIVATE="1111111111111111111111111111111111111111111"
    REALITY_PUBLIC="2222222222222222222222222222222222222222222"
fi

REALITY_SHORTID=$(openssl rand -hex 4)
REALITY_DEST="login.microsoftonline.com:443"
REALITY_SNI="login.microsoftonline.com"

# Prepare config directory
mkdir -p /usr/local/xray

# ============================
#   Build config.json
# ============================

cat >/usr/local/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "Rami-VLESS-WS-1",
      "listen": "0.0.0.0",
      "port": ${PORT_VLESS_WS},
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${VLESS_UUID}" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },
    {
      "tag": "Rami-VMESS-WS-1",
      "listen": "0.0.0.0",
      "port": ${PORT_VMESS_WS},
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "${VMESS_UUID}" }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },
    {
      "tag": "Rami-TROJAN-WS-1",
      "listen": "0.0.0.0",
      "port": ${PORT_TROJAN_WS},
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "${TROJAN_PASS}" }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },
    {
      "tag": "Rami-SS-WS-1",
      "listen": "0.0.0.0",
      "port": ${PORT_SS_WS},
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-128-gcm",
        "password": "${SS_PASS}",
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },

    {
      "tag": "Rami-VLESS-WS-2",
      "listen": "0.0.0.0",
      "port": ${PORT_VLESS2_WS},
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${VLESS_UUID2}" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },
    {
      "tag": "Rami-VMESS-WS-2",
      "listen": "0.0.0.0",
      "port": ${PORT_VMESS2_WS},
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "${VMESS_UUID2}" }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },
    {
      "tag": "Rami-TROJAN-WS-2",
      "listen": "0.0.0.0",
      "port": ${PORT_TROJAN2_WS},
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "${TROJAN_PASS2}" }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },
    {
      "tag": "Rami-SS-WS-2",
      "listen": "0.0.0.0",
      "port": ${PORT_SS2_WS},
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-128-gcm",
        "password": "${SS_PASS2}",
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },

    {
      "tag": "Rami-VLESS-WS-3",
      "listen": "0.0.0.0",
      "port": ${PORT_VLESS3_WS},
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${VLESS_UUID3}" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },
    {
      "tag": "Rami-VMESS-WS-3",
      "listen": "0.0.0.0",
      "port": ${PORT_VMESS3_WS},
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "${VMESS_UUID3}" }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },
    {
      "tag": "Rami-TROJAN-WS-3",
      "listen": "0.0.0.0",
      "port": ${PORT_TROJAN3_WS},
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "${TROJAN_PASS3}" }]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },
    {
      "tag": "Rami-SS-WS-3",
      "listen": "0.0.0.0",
      "port": ${PORT_SS3_WS},
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-128-gcm",
        "password": "${SS_PASS3}",
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },

    {
      "tag": "Rami-REALITY",
      "listen": "0.0.0.0",
      "port": ${PORT_REALITY},
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${VLESS_UUID}", "flow": "xtls-rprx-vision" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${REALITY_DEST}",
          "xver": 0,
          "serverNames": ["${REALITY_SNI}"],
          "privateKey": "${REALITY_PRIVATE}",
          "shortIds": ["${REALITY_SHORTID}"]
        }
      }
    },
    {
      "tag": "Rami-TLS",
      "listen": "0.0.0.0",
      "port": ${PORT_TLS},
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${VLESS_UUID2}" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/usr/local/xray/self-cert.pem",
              "keyFile": "/usr/local/xray/self-key.pem"
            }
          ]
        },
        "wsSettings": { "path": "${WS_PATH}" }
      }
    },

    {
      "tag": "Rami-VLESS-TCP",
      "listen": "0.0.0.0",
      "port": ${PORT_VLESS_TCP},
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${VLESS_UUID3}" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    },
    {
      "tag": "Rami-VMESS-TCP",
      "listen": "0.0.0.0",
      "port": ${PORT_VMESS_TCP},
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "${VMESS_UUID}" }]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    },
    {
      "tag": "Rami-TROJAN-TCP",
      "listen": "0.0.0.0",
      "port": ${PORT_TROJAN_TCP},
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "${TROJAN_PASS}" }]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    },
    {
      "tag": "Rami-SS-TCP",
      "listen": "0.0.0.0",
      "port": ${PORT_SS_TCP},
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-128-gcm",
        "password": "${SS_PASS}",
        "network": "tcp,udp"
      }
    },
    {
      "tag": "Rami-HYSTERIA2",
      "listen": "0.0.0.0",
      "port": ${PORT_HYSTERIA2},
      "protocol": "hysteria2",
      "settings": {
        "clients": [{ "password": "${TROJAN_PASS2}" }],
        "obfs": "salamander"
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "blocked" }
  ]
}
EOF

# Self-signed cert for TLS Fake
if [ ! -f /usr/local/xray/self-cert.pem ]; then
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout /usr/local/xray/self-key.pem \
    -out /usr/local/xray/self-cert.pem \
    -days 365 \
    -subj "/CN=${SERVER_IP}"
fi

# ============================
#   Build RamtinConfigs.txt
# ============================

CONFIG_FILE="/root/RamtinConfigs.txt"
> "$CONFIG_FILE"

# Helper: SS base64
ss_encode() {
  local METHOD="$1"
  local PASS="$2"
  local HOST="$3"
  local PORT="$4"
  local RAW="${METHOD}:${PASS}@${HOST}:${PORT}"
  echo -n "$RAW" | base64 -w0
}

# Helper: VMESS base64
vmess_encode() {
  local HOST="$1"
  local PORT="$2"
  local UUID="$3"
  local NAME="$4"
  local JSON=$(cat <<J
{
  "v": "2",
  "ps": "${NAME}",
  "add": "${HOST}",
  "port": "${PORT}",
  "id": "${UUID}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "${HOST}",
  "path": "${WS_PATH}",
  "tls": ""
}
J
)
  echo -n "$JSON" | base64 -w0
}

# Names
NAME_VLESS_WS="$(generate_prefix)-VLESS-${PORT_VLESS_WS}"
NAME_VMESS_WS="$(generate_prefix)-VMESS-${PORT_VMESS_WS}"
NAME_TROJAN_WS="$(generate_prefix)-TROJAN-${PORT_TROJAN_WS}"
NAME_SS_WS="$(generate_prefix)-SS-${PORT_SS_WS}"

NAME_VLESS2_WS="$(generate_prefix)-VLESS-${PORT_VLESS2_WS}"
NAME_VMESS2_WS="$(generate_prefix)-VMESS-${PORT_VMESS2_WS}"
NAME_TROJAN2_WS="$(generate_prefix)-TROJAN-${PORT_TROJAN2_WS}"
NAME_SS2_WS="$(generate_prefix)-SS-${PORT_SS2_WS}"

NAME_VLESS3_WS="$(generate_prefix)-VLESS-${PORT_VLESS3_WS}"
NAME_VMESS3_WS="$(generate_prefix)-VMESS-${PORT_VMESS3_WS}"
NAME_TROJAN3_WS="$(generate_prefix)-TROJAN-${PORT_TROJAN3_WS}"
NAME_SS3_WS="$(generate_prefix)-SS-${PORT_SS3_WS}"

NAME_REALITY="$(generate_prefix)-REALITY-${PORT_REALITY}"
NAME_TLS="$(generate_prefix)-TLS-${PORT_TLS}"

NAME_VLESS_TCP="$(generate_prefix)-VLESS-TCP-${PORT_VLESS_TCP}"
NAME_VMESS_TCP="$(generate_prefix)-VMESS-TCP-${PORT_VMESS_TCP}"
NAME_TROJAN_TCP="$(generate_prefix)-TROJAN-TCP-${PORT_TROJAN_TCP}"
NAME_SS_TCP="$(generate_prefix)-SS-TCP-${PORT_SS_TCP}"
NAME_HYSTERIA2="$(generate_prefix)-HYSTERIA2-${PORT_HYSTERIA2}"

# 1) VLESS WS
echo "vless://${VLESS_UUID}@${SERVER_IP}:${PORT_VLESS_WS}?security=none&encryption=none&type=ws&path=${WS_PATH}&host=${SERVER_IP}#${NAME_VLESS_WS}" >>"$CONFIG_FILE"

# 2) VMESS WS
VMESS_LINK_1=$(vmess_encode "${SERVER_IP}" "${PORT_VMESS_WS}" "${VMESS_UUID}" "${NAME_VMESS_WS}")
echo "vmess://${VMESS_LINK_1}#${NAME_VMESS_WS}" >>"$CONFIG_FILE"

# 3) TROJAN WS
echo "trojan://${TROJAN_PASS}@${SERVER_IP}:${PORT_TROJAN_WS}?security=none&type=ws&path=${WS_PATH}&host=${SERVER_IP}#${NAME_TROJAN_WS}" >>"$CONFIG_FILE"

# 4) SS WS
SS_B64_1=$(ss_encode "aes-128-gcm" "${SS_PASS}" "${SERVER_IP}" "${PORT_SS_WS}")
echo "ss://${SS_B64_1}#${NAME_SS_WS}" >>"$CONFIG_FILE"

# 5) VLESS WS 2
echo "vless://${VLESS_UUID2}@${SERVER_IP}:${PORT_VLESS2_WS}?security=none&encryption=none&type=ws&path=${WS_PATH}&host=${SERVER_IP}#${NAME_VLESS2_WS}" >>"$CONFIG_FILE"

# 6) VMESS WS 2
VMESS_LINK_2=$(vmess_encode "${SERVER_IP}" "${PORT_VMESS2_WS}" "${VMESS_UUID2}" "${NAME_VMESS2_WS}")
echo "vmess://${VMESS_LINK_2}#${NAME_VMESS2_WS}" >>"$CONFIG_FILE"

# 7) TROJAN WS 2
echo "trojan://${TROJAN_PASS2}@${SERVER_IP}:${PORT_TROJAN2_WS}?security=none&type=ws&path=${WS_PATH}&host=${SERVER_IP}#${NAME_TROJAN2_WS}" >>"$CONFIG_FILE"

# 8) SS WS 2
SS_B64_2=$(ss_encode "aes-128-gcm" "${SS_PASS2}" "${SERVER_IP}" "${PORT_SS2_WS}")
echo "ss://${SS_B64_2}#${NAME_SS2_WS}" >>"$CONFIG_FILE"

# 9) VLESS WS 3
echo "vless://${VLESS_UUID3}@${SERVER_IP}:${PORT_VLESS3_WS}?security=none&encryption=none&type=ws&path=${WS_PATH}&host=${SERVER_IP}#${NAME_VLESS3_WS}" >>"$CONFIG_FILE"

# 10) VMESS WS 3
VMESS_LINK_3=$(vmess_encode "${SERVER_IP}" "${PORT_VMESS3_WS}" "${VMESS_UUID3}" "${NAME_VMESS3_WS}")
echo "vmess://${VMESS_LINK_3}#${NAME_VMESS3_WS}" >>"$CONFIG_FILE"

# 11) TROJAN WS 3
echo "trojan://${TROJAN_PASS3}@${SERVER_IP}:${PORT_TROJAN3_WS}?security=none&type=ws&path=${WS_PATH}&host=${SERVER_IP}#${NAME_TROJAN3_WS}" >>"$CONFIG_FILE"

# 12) SS WS 3
SS_B64_3=$(ss_encode "aes-128-gcm" "${SS_PASS3}" "${SERVER_IP}" "${PORT_SS3_WS}")
echo "ss://${SS_B64_3}#${NAME_SS3_WS}" >>"$CONFIG_FILE"

# 13) REALITY
echo "vless://${VLESS_UUID}@${SERVER_IP}:${PORT_REALITY}?security=reality&encryption=none&pbk=${REALITY_PUBLIC}&sid=${REALITY_SHORTID}&type=tcp&flow=xtls-rprx-vision#${NAME_REALITY}" >>"$CONFIG_FILE"

# 14) TLS (WS + Fake TLS)
echo "vless://${VLESS_UUID2}@${SERVER_IP}:${PORT_TLS}?security=tls&encryption=none&type=ws&path=${WS_PATH}&host=${SERVER_IP}#${NAME_TLS}" >>"$CONFIG_FILE"

# 15) VLESS TCP
echo "vless://${VLESS_UUID3}@${SERVER_IP}:${PORT_VLESS_TCP}?security=none&encryption=none&type=tcp#${NAME_VLESS_TCP}" >>"$CONFIG_FILE"

# 16) VMESS TCP
VMESS_TCP_JSON=$(cat <<J
{
  "v": "2",
  "ps": "${NAME_VMESS_TCP}",
  "add": "${SERVER_IP}",
  "port": "${PORT_VMESS_TCP}",
  "id": "${VMESS_UUID}",
  "aid": "0",
  "scy": "auto",
  "net": "tcp",
  "type": "none",
  "host": "",
  "path": "",
  "tls": ""
}
J
)
VMESS_TCP_B64=$(echo -n "$VMESS_TCP_JSON" | base64 -w0)
echo "vmess://${VMESS_TCP_B64}#${NAME_VMESS_TCP}" >>"$CONFIG_FILE"

# 17) TROJAN TCP
echo "trojan://${TROJAN_PASS}@${SERVER_IP}:${PORT_TROJAN_TCP}?security=none&type=tcp#${NAME_TROJAN_TCP}" >>"$CONFIG_FILE"

# 18) SS TCP
SS_B64_TCP=$(ss_encode "aes-128-gcm" "${SS_PASS}" "${SERVER_IP}" "${PORT_SS_TCP}")
echo "ss://${SS_B64_TCP}#${NAME_SS_TCP}" >>"$CONFIG_FILE"

# 19) HYSTERIA2
echo "hysteria2://${TROJAN_PASS2}@${SERVER_IP}:${PORT_HYSTERIA2}?obfs=salamander&protocol=udp#${NAME_HYSTERIA2}" >>"$CONFIG_FILE"

# Restart Xray
systemctl restart xray || xray -config /usr/local/xray/config.json &

echo "✅ Done."
echo "📄 All 19 configs saved in: ${CONFIG_FILE}"
