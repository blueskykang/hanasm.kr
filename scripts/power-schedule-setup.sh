#!/bin/bash
# 야간 절전 — 0시 정상 종료 + BIOS RTC 예약부팅 안내
# 실행: bash power-schedule-setup.sh
# 절약: 하루 8시간 off → 월 약 1.1만원 (누진 3단계 기준)

set -e

echo "=== 야간 절전 스케줄 설정 (0시 종료 / 8시 부팅) ==="
echo ""
echo "⚠️ 켜기는 소프트웨어로 불가 → BIOS 예약부팅 필수 (아래 안내)"
echo ""

# 1. VM 정상 종료 후 호스트 셧다운 스크립트
cat > /usr/local/bin/nightly-shutdown.sh <<'EOF'
#!/bin/bash
# 0시 야간 종료 — VM 정상 종료 후 호스트 셧다운
LOG=/var/log/nightly-shutdown.log
echo "$(date) 야간 종료 시작" >> $LOG

# 실행 중인 VM 정상 종료 (최대 120초 대기)
for vmid in $(qm list | awk 'NR>1 && $3=="running" {print $1}'); do
    echo "$(date) VM $vmid shutdown" >> $LOG
    qm shutdown $vmid --timeout 120 >> $LOG 2>&1 || qm stop $vmid >> $LOG 2>&1
done

sleep 10
echo "$(date) 호스트 셧다운" >> $LOG
/sbin/shutdown -h now
EOF
chmod +x /usr/local/bin/nightly-shutdown.sh
echo "[OK] /usr/local/bin/nightly-shutdown.sh 생성"

# 2. cron 등록 (0시)
CRON="/etc/cron.d/nightly-shutdown"
echo "# 야간 절전 — 매일 0시 정상 종료" > "$CRON"
echo "0 0 * * * root /usr/local/bin/nightly-shutdown.sh" >> "$CRON"
echo "[OK] cron 등록: 매일 0시 종료"

# 3. 백업/동기화 작업은 가동시간(8~24시)으로
echo ""
echo "=== 확인: 백업·동기화 작업 시간 ==="
echo "0~8시에 예약된 작업이 있으면 8시 이후로 옮기세요:"
grep -rE "^[0-7] |^0 [0-7]" /etc/cron.d/ /etc/crontab 2>/dev/null | grep -v nightly-shutdown || echo "  (0~8시 예약 작업 없음)"

cat <<'GUIDE'

========================================
 BIOS 예약부팅 설정 (수동 — 필수)
========================================
X570-E BIOS 진입 (Del 키) →
  Advanced → APM Configuration →
    Power On By RTC = [Enabled]
    RTC Alarm Date = Every Day
    Hour = 7, Minute = 50   (07:50 부팅, 8시 전 준비완료)

또는 "ErP Ready" 가 켜져있으면 RTC 부팅이 막힐 수 있으니 Disabled 확인.

========================================
 검증
========================================
- 0시에 자동 종료되는지 로그 확인: cat /var/log/nightly-shutdown.log
- 07:50에 자동 부팅되는지 확인
- 메일: 1~2주 관찰 (야간 수신 지연 문제 없는지)

되돌리기: rm /etc/cron.d/nightly-shutdown && BIOS RTC Disabled
GUIDE
