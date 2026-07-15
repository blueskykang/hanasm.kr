#!/bin/bash
# X570-E 교체 전 준비 — 현황 백업·기록
# 실행: bash x570e-pre-migration.sh
# 교체 후 x570e-post-migration.sh 에서 이 기록을 참고해 재매핑한다.

set -e

BK="/root/x570e-migration-$(date +%Y%m%d)"
mkdir -p "$BK"
echo "=== 백업 위치: $BK ==="

# 1. 핵심 설정 백업
tar czf "$BK/pve-etc.tar.gz" /etc/pve/ 2>/dev/null
cp /etc/network/interfaces "$BK/interfaces.old"
cp /etc/default/grub "$BK/grub.old"
cp -r /etc/pve/qemu-server "$BK/qemu-server.old"
[ -f /etc/modprobe.d/vfio.conf ] && cp /etc/modprobe.d/vfio.conf "$BK/"
echo "[OK] 설정 백업 완료"

# 2. 현재 NIC 이름·MAC 기록
echo "=== NIC 현황 ===" | tee "$BK/nics.txt"
ip -br link show | tee -a "$BK/nics.txt"
echo "" | tee -a "$BK/nics.txt"
echo "interfaces 파일의 사용 NIC:" | tee -a "$BK/nics.txt"
grep -E "iface|bridge_ports|address" /etc/network/interfaces | tee -a "$BK/nics.txt"

# 3. PCI 장치·주소 기록 (패스스루 재매핑용)
echo "=== PCI 장치 목록 ===" | tee "$BK/pci.txt"
lspci -nn | tee -a "$BK/pci.txt"
echo "" | tee -a "$BK/pci.txt"
echo "=== VM 패스스루(hostpci) 설정 ===" | tee -a "$BK/pci.txt"
grep -H "hostpci" /etc/pve/qemu-server/*.conf 2>/dev/null | tee -a "$BK/pci.txt" || echo "hostpci 없음"

# 4. IOMMU 그룹 기록
echo "=== IOMMU 그룹 현황 ===" > "$BK/iommu.txt"
if [ -d /sys/kernel/iommu_groups ]; then
    for d in /sys/kernel/iommu_groups/*/devices/*; do
        n=${d#*/iommu_groups/}; n=${n%%/*}
        printf "Group %s: %s\n" "$n" "$(lspci -nns ${d##*/})"
    done | sort -V >> "$BK/iommu.txt"
    cat "$BK/iommu.txt"
else
    echo "IOMMU 비활성 상태" | tee -a "$BK/iommu.txt"
fi

# 5. 현재 GRUB 파라미터
echo "=== GRUB cmdline ===" | tee "$BK/grub-cmdline.txt"
grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub | tee -a "$BK/grub-cmdline.txt"

echo ""
echo "========================================"
echo " 교체 전 준비 완료"
echo " 기록 위치: $BK"
echo "========================================"
echo ""
echo "다음:"
echo " 1. 이 폴더($BK)를 다른 곳에도 복사 권장 (USB 등)"
echo " 2. VM 정상 종료: for v in 100 101 102; do qm shutdown \$v; done"
echo " 3. 호스트 셧다운 후 보드 교체"
echo " 4. 교체 후 GT 635 콘솔에서 x570e-post-migration.sh 실행"
