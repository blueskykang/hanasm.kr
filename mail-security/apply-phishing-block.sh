#!/bin/bash
# 피싱 차단 규칙 적용 스크립트 — VM 102 NAS (Synology MailServer / Postfix)
#
# 실행: sudo bash apply-phishing-block.sh
#
# ⚠️ Synology 주의:
#  - Synology MailServer 패키지가 Postfix 설정을 관리합니다. main.cf 직접 수정은
#    패키지 업데이트/재시작 시 덮어써질 수 있습니다.
#  - 이 스크립트는 백업 후 적용하며, 적용 결과를 출력합니다.
#  - 적용 후 MailServer 패키지를 껐다 켜면 초기화될 수 있으니, 그 경우 재실행하세요.

set -e

# Postfix 설정 경로 자동 탐색
PF_DIR="/etc/postfix"
[ -d "$PF_DIR" ] || PF_DIR="$(postconf -h config_directory 2>/dev/null || echo /etc/postfix)"
echo "=== Postfix 설정 경로: $PF_DIR ==="

# 스크립트 위치 기준으로 소스 파일 찾기
SRC="$(cd "$(dirname "$0")" && pwd)"

# 백업
BK="$PF_DIR/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
cp "$PF_DIR/main.cf" "$BK/" 2>/dev/null || true
cp "$PF_DIR/sender_access" "$BK/" 2>/dev/null || true
cp "$PF_DIR/header_checks.pcre" "$BK/" 2>/dev/null || true
echo "백업: $BK"

# 1. sender_access 배치 + 맵 생성
cp "$SRC/sender_access" "$PF_DIR/sender_access"
postmap "$PF_DIR/sender_access"
echo "[OK] sender_access 적용"

# 2. header_checks 배치
cp "$SRC/header_checks.pcre" "$PF_DIR/header_checks.pcre"
echo "[OK] header_checks.pcre 배치"

# 3. PCRE 지원 확인
if ! postconf -m | grep -q pcre; then
    echo "[경고] 이 Postfix는 PCRE 미지원. header_checks[1] IP 규칙이 안 먹을 수 있음."
    echo "        regexp 로 바꾸려면 header_checks.pcre 를 regexp 문법으로 변환 필요."
fi

# 4. main.cf 에 참조 추가 (중복 방지)
add_cf() {
    local key="$1" val="$2"
    if postconf -h "$key" 2>/dev/null | grep -q "$val"; then
        echo "[skip] $key 에 이미 $val 있음"
    else
        local cur; cur="$(postconf -h "$key" 2>/dev/null || true)"
        if [ -z "$cur" ]; then
            postconf -e "$key = $val"
        else
            postconf -e "$key = $cur, $val"
        fi
        echo "[OK] $key += $val"
    fi
}
add_cf header_checks "pcre:$PF_DIR/header_checks.pcre"
add_cf smtpd_sender_restrictions "check_sender_access hash:$PF_DIR/sender_access"

# 5. 문법 점검 + 리로드
echo "=== postfix check ==="
postfix check && echo "문법 OK"

echo "=== reload ==="
postfix reload || systemctl reload postfix || synoservice --restart pkgctl-MailServer

echo ""
echo "=== 적용 완료 ==="
echo "현재 값 확인:"
postconf -h header_checks
postconf -h smtpd_sender_restrictions
echo ""
echo "테스트: 로그에서 REJECT 확인"
echo "  tail -f /var/log/mail.log | grep -Ei 'reject|172.245.174.85'"
