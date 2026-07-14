#!/bin/bash
# 보드 교체 전 Proxmox 설정 정리 스크립트
# 실행: bash pre-migration.sh
# 주의: 실행 전 /etc/pve/ 백업 필수

set -e

BACKUP_DIR="/root/pre-migration-backup-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

echo "=== 백업 시작: $BACKUP_DIR ==="
cp /etc/default/grub "$BACKUP_DIR/grub.bak"
cp /etc/network/interfaces "$BACKUP_DIR/interfaces.bak"
cp -r /etc/pve/qemu-server/ "$BACKUP_DIR/qemu-server.bak"
[ -f /etc/modprobe.d/vfio.conf ] && cp /etc/modprobe.d/vfio.conf "$BACKUP_DIR/vfio.conf.bak"
echo "백업 완료"

# --- 1. GRUB에서 7900X3D / RTX 3080 관련 파라미터 제거 ---
echo "=== GRUB 설정 정리 ==="
GRUB_FILE="/etc/default/grub"

# 제거 대상 파라미터
PARAMS_TO_REMOVE="isolcpus=[^ ]* nohz_full=[^ ]* rcu_nocbs=[^ ]* vfio-pci.ids=1022:43f7"

CURRENT_LINE=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT' "$GRUB_FILE")
echo "현재: $CURRENT_LINE"

NEW_LINE=$(echo "$CURRENT_LINE" | sed \
  -e 's/isolcpus=[^ "]*//g' \
  -e 's/nohz_full=[^ "]*//g' \
  -e 's/rcu_nocbs=[^ "]*//g' \
  -e 's/vfio-pci\.ids=1022:43f7//g' \
  -e 's/  */ /g')

sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT.*|${NEW_LINE}|" "$GRUB_FILE"
echo "변경후: $(grep '^GRUB_CMDLINE_LINUX_DEFAULT' $GRUB_FILE)"

# --- 2. vfio.conf에서 AMD 600 USB 관련 설정 제거 ---
echo "=== vfio.conf 정리 ==="
if [ -f /etc/modprobe.d/vfio.conf ]; then
    echo "현재 vfio.conf:"
    cat /etc/modprobe.d/vfio.conf
    # AMD 600 USB 관련 ids 제거 (필요시 수동 확인 후 주석 처리)
    sed -i '/# AMD 600 USB/d' /etc/modprobe.d/vfio.conf
    echo "정리 후:"
    cat /etc/modprobe.d/vfio.conf
else
    echo "vfio.conf 없음 — 스킵"
fi

# --- 3. VM 100, 101, 102 CPU affinity 제거 ---
echo "=== VM affinity 제거 ==="
for VMID in 100 101 102; do
    CONF="/etc/pve/qemu-server/${VMID}.conf"
    if [ -f "$CONF" ]; then
        echo "VM $VMID 처리 중..."
        sed -i '/^affinity:/d' "$CONF"
        echo "  affinity 제거 완료"
    else
        echo "  VM $VMID 설정 없음 — 스킵"
    fi
done

# --- 4. Windows VM 백업 ---
echo "=== VM 100 Windows 백업 (vzdump) ==="
echo "수동 실행 필요 (시간이 오래 걸림):"
echo "  vzdump 100 --storage local --compress zstd --mode snapshot"
echo "백업 파일 위치: /var/lib/vz/dump/"

# --- 5. 적용 ---
echo "=== GRUB 및 initramfs 업데이트 ==="
update-grub
update-initramfs -u

echo ""
echo "=== 보드 교체 전 정리 완료 ==="
echo "백업 위치: $BACKUP_DIR"
echo ""
echo "다음 단계:"
echo "  1. VM 100 vzdump 백업 실행"
echo "  2. DSM SSD 캐시 제거 (840 PRO 256GB x2)"
echo "  3. 서버 셧다운 후 하드웨어 교체"
