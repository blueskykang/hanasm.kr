#!/bin/bash
# X570-E 교체 후 설정 — NIC 재매핑, ACS override 제거, 패스스루 재설정
# 실행: bash x570e-post-migration.sh  (⚠️ GT 635 물리 콘솔에서)
# 교체 전 x570e-pre-migration.sh 기록(/root/x570e-migration-*)을 참고한다.

set -e

BK="$(ls -d /root/x570e-migration-* 2>/dev/null | tail -1)"
echo "=== 교체 전 기록: ${BK:-없음} ==="

# ─────────────────────────────────────────────
# 1. 새 NIC 이름 확인 + interfaces 재매핑 (수동 확인 필요)
# ─────────────────────────────────────────────
echo ""
echo "=== [1] 현재 NIC 목록 (X570-E: Realtek 2.5G + Intel 1G) ==="
ip -br link show
echo ""
echo "교체 전 NIC (참고):"
[ -f "$BK/nics.txt" ] && cat "$BK/nics.txt"
echo ""
echo ">>> /etc/network/interfaces 를 새 NIC 이름으로 수정해야 SSH 복구됩니다."
echo ">>> 예: 옛 enp5s0 → 새 이름(위 목록에서 확인)"
echo ">>> 지금 수동 편집: nano /etc/network/interfaces  후 systemctl restart networking"
read -p "interfaces 수정을 마쳤으면 Enter (건너뛰려면 Ctrl+C): "
systemctl restart networking && echo "[OK] networking 재시작"

# ─────────────────────────────────────────────
# 2. ACS override 제거 (X570은 IOMMU 네이티브 분리)
# ─────────────────────────────────────────────
echo ""
echo "=== [2] GRUB에서 ACS override 제거 ==="
GRUB=/etc/default/grub
cp "$GRUB" "${GRUB}.pre-x570"
sed -i 's/ *pcie_acs_override=[^ "]*//g' "$GRUB"
echo "변경 후: $(grep GRUB_CMDLINE_LINUX_DEFAULT $GRUB)"
echo "[OK] ACS override 제거 (IOMMU 분리 확인 후 유지)"

# ─────────────────────────────────────────────
# 3. IOMMU 그룹 재확인 (분리 잘 됐는지)
# ─────────────────────────────────────────────
echo ""
echo "=== [3] 새 IOMMU 그룹 ==="
if [ -d /sys/kernel/iommu_groups ]; then
    for d in /sys/kernel/iommu_groups/*/devices/*; do
        n=${d#*/iommu_groups/}; n=${n%%/*}
        printf "Group %s: %s\n" "$n" "$(lspci -nns ${d##*/})"
    done | sort -V | grep -Ei "VGA|3D|SATA|LSI|Non-Volatile|Ethernet" || true
    echo ""
    echo ">>> LSI HBA, GTX 1650, GT 635 이 각각 독립 그룹인지 확인."
    echo ">>> 만약 한 그룹에 묶였으면 GRUB에 pcie_acs_override 다시 추가 필요."
else
    echo "⚠️ IOMMU 비활성 — BIOS에서 IOMMU/SVM 활성화 확인!"
fi

# ─────────────────────────────────────────────
# 4. 패스스루 PCI 주소 재매핑 (수동)
# ─────────────────────────────────────────────
echo ""
echo "=== [4] 패스스루 주소 재매핑 (수동) ==="
echo "새 PCI 주소:"
lspci -nn | grep -Ei "LSI|SAS|VGA|3D" || true
echo ""
echo "교체 전 hostpci 설정 (참고):"
[ -f "$BK/pci.txt" ] && grep hostpci "$BK/pci.txt" || echo "(기록 없음)"
echo ""
echo ">>> VM 102(NAS)의 LSI HBA 주소를 새 주소로 수정:"
echo ">>>   nano /etc/pve/qemu-server/102.conf"
echo ">>>   hostpci0: <새주소>,pcie=1"
echo ">>> GTX 1650 에뮬 VM도 동일하게 hostpci 설정"

# ─────────────────────────────────────────────
# 5. GRUB / initramfs 갱신
# ─────────────────────────────────────────────
echo ""
echo "=== [5] GRUB / initramfs 갱신 ==="
update-grub
update-initramfs -u
echo "[OK] 갱신 완료"

echo ""
echo "========================================"
echo " 교체 후 기본 설정 완료 — 재부팅 필요"
echo "========================================"
echo "확인 체크리스트:"
echo "  □ interfaces NIC 이름 수정 → 네트워크 정상?"
echo "  □ IOMMU 그룹 분리 확인 (ACS override 없이)"
echo "  □ VM 102 HBA 주소 재매핑"
echo "  □ 에뮬 VM GPU 주소 설정 (해당 시)"
echo "  □ reboot 후 VM 100/101/102 부팅 테스트"
echo ""
echo "  reboot"
