#!/bin/bash
# Proxmox 호스트 + VM 102 NAS 상태를 Discord 웹훅으로 전송

WEBHOOK_URL="${DISCORD_WEBHOOK_URL}"
NAS_HOST="VM102_IP"  # VM 102 내부 IP로 교체
NAS_USER="blueskykang"

# --- Proxmox 호스트 정보 ---
PVE_UPTIME=$(uptime -p)
PVE_LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
PVE_MEM=$(free -h | awk '/^Mem:/ {printf "%s / %s (%.0f%%)", $3, $2, $3/$2*100}')

# --- VM 102 NAS 정보 (SSH) ---
NAS_INFO=$(ssh -o StrictHostKeyChecking=no "${NAS_USER}@${NAS_HOST}" bash <<'EOF'
echo "uptime=$(uptime -p)"
echo "load=$(cut -d' ' -f1-3 /proc/loadavg)"
echo "cpu=$(top -bn1 | grep 'Cpu(s)' | awk '{print 100-$8}')%"
echo "mem=$(free -h | awk '/^Mem:/ {printf "%s/%s", $3, $2}')"
echo "swap=$(free -h | awk '/^Swap:/ {printf "%s/%s", $3, $2}')"
echo "disk=$(df -h / | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')"
EOF
)

parse() { echo "$NAS_INFO" | grep "^$1=" | cut -d= -f2-; }

PAYLOAD=$(cat <<JSON
{
  "embeds": [{
    "title": "서버 상태 보고",
    "color": 3066993,
    "fields": [
      {"name": "🖥️ Proxmox 업타임", "value": "${PVE_UPTIME}", "inline": true},
      {"name": "⚡ PVE Load", "value": "${PVE_LOAD}", "inline": true},
      {"name": "💾 PVE 메모리", "value": "${PVE_MEM}", "inline": false},
      {"name": "📦 NAS 업타임", "value": "$(parse uptime)", "inline": true},
      {"name": "⚡ NAS Load", "value": "$(parse load)", "inline": true},
      {"name": "🧠 NAS CPU", "value": "$(parse cpu)", "inline": true},
      {"name": "💾 NAS 메모리", "value": "$(parse mem)", "inline": true},
      {"name": "🔄 NAS Swap", "value": "$(parse swap)", "inline": true},
      {"name": "💿 NAS 디스크", "value": "$(parse disk)", "inline": true}
    ],
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }]
}
JSON
)

curl -s -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}"
