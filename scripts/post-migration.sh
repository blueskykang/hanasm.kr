#!/bin/bash
# 보드 교체 후 Proxmox 설정 스크립트 (Ryzen 3600 + X370 Pro)
# 실행: bash post-migration.sh
# 주의: 네트워크 인터페이스 이름 확인 후 실행

set -e

# =============================================
# 실행 전 확인 필요한 변수
# =============================================
# ip link show 로 실제 인터페이스 이름 확인 후 수정
NEW_NIC="enp1s0"       # I350-T2 첫 번째 포트 (실제 이름으로 교체)
BRIDGE="vmbr0"
# =============================================

echo "=== 현재 네트워크 인터페이스 목록 ==="
ip link show

echo ""
echo "위 목록에서 I350-T2 인터페이스 이름을 확인하고"
echo "스크립트 상단 NEW_NIC 변수를 수정 후 계속하세요."
echo ""
read -p "계속하려면 Enter, 중단하려면 Ctrl+C: "

# --- 1. GRUB: ACS Override 추가 ---
echo "=== GRUB ACS Override 설정 ==="
GRUB_FILE="/etc/default/grub"
CURRENT=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT' "$GRUB_FILE")

if echo "$CURRENT" | grep -q "pcie_acs_override"; then
    echo "이미 설정됨 — 스킵"
else
    NEW=$(echo "$CURRENT" | sed 's/"$/ pcie_acs_override=downstream,multifunction"/')
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT.*|${NEW}|" "$GRUB_FILE"
    echo "추가 완료: $(grep '^GRUB_CMDLINE_LINUX_DEFAULT' $GRUB_FILE)"
fi

# --- 2. IOMMU unsafe interrupts 허용 ---
echo "=== IOMMU unsafe interrupts 설정 ==="
CONF="/etc/modprobe.d/iommu_unsafe_interrupts.conf"
if [ ! -f "$CONF" ]; then
    echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > "$CONF"
    echo "생성 완료: $CONF"
else
    echo "이미 존재 — 내용 확인:"
    cat "$CONF"
fi

# --- 3. 네트워크 인터페이스 설정 ---
echo "=== /etc/network/interfaces 업데이트 ==="
IFACE_FILE="/etc/network/interfaces"
cp "$IFACE_FILE" "${IFACE_FILE}.bak-$(date +%Y%m%d)"

if grep -q "$NEW_NIC" "$IFACE_FILE"; then
    echo "이미 $NEW_NIC 설정됨 — 스킵"
else
    echo "현재 인터페이스 설정:"
    cat "$IFACE_FILE"
    echo ""
    echo "수동으로 $IFACE_FILE 편집 필요:"
    echo "  기존 NIC 이름을 $NEW_NIC 으로 교체"
fi

# --- 4. IOMMU 그룹 확인 ---
echo "=== IOMMU 그룹 확인 ==="
echo "LSI HBA 및 I350-T2 그룹 확인:"
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf "Group %s: " "$n"
    lspci -nns "${d##*/}"
done 2>/dev/null | grep -E "LSI|HBA|1000:|Ethernet|Intel|8086:1521" || echo "lspci 결과 없음"

# --- 5. 840 PRO SATA 스토리지 등록 ---
echo ""
echo "=== 840 PRO 스토리지 등록 (수동) ==="
echo "Proxmox WebUI → Datacenter → Storage → Add → Directory"
echo "또는 CLI:"
echo "  pvesm add dir win840pro --path /dev/sdX  # sdX는 실제 디스크로 교체"
echo ""
echo "확인 명령:"
echo "  lsblk -d -o NAME,SIZE,MODEL | grep -i samsung"

# --- 6. VM 100 Windows 복원 ---
echo ""
echo "=== VM 100 복원 (수동) ==="
echo "1. lsblk 로 840 PRO 디스크 이름 확인"
echo "2. 스토리지 등록 후:"
echo "   qmrestore /var/lib/vz/dump/vzdump-qemu-100-*.vma.zst 100 \\"
echo "     --storage <840pro-storage> --unique"
echo "3. VM 100 설정에서 디스크 크기 확인 및 축소"

# --- 7. VM 102 LSI HBA 패스스루 재설정 ---
echo ""
echo "=== LSI HBA 패스스루 재설정 ==="
echo "IOMMU 그룹 확인 후 VM 102 설정 편집:"
echo "  vi /etc/pve/qemu-server/102.conf"
echo "  hostpci0: <BUS:DEVICE.FUNCTION>,pcie=1"

# --- 8. 최종 적용 ---
echo ""
echo "=== GRUB 및 initramfs 업데이트 ==="
update-grub
update-initramfs -u

echo ""
echo "=== 설정 완료 — 재부팅 필요 ==="
echo "reboot"
