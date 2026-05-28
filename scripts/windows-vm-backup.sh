#!/bin/bash
# VM 100 Windows vzdump 백업 스크립트
# 보드 교체 전 실행 — 840 PRO 256GB에 복원 용도

STORAGE="local"   # 백업 저장 스토리지 (pvesm list 로 확인)
VMID=100

echo "=== VM $VMID 상태 확인 ==="
qm status $VMID

echo ""
echo "=== 현재 디스크 사용량 확인 ==="
qm config $VMID | grep -E "^(scsi|virtio|ide|sata)"

echo ""
echo "=== vzdump 백업 시작 ==="
echo "예상 소요 시간: 실제 사용량 ~170GB 기준 30~60분"
vzdump $VMID \
    --storage $STORAGE \
    --compress zstd \
    --mode snapshot \
    --notes-template "보드교체전백업-$(date +%Y%m%d)"

echo ""
echo "=== 백업 파일 확인 ==="
ls -lh /var/lib/vz/dump/vzdump-qemu-${VMID}-*.vma.zst 2>/dev/null || \
    pvesm list $STORAGE | grep "vzdump-qemu-${VMID}"

echo ""
echo "복원 명령어 (보드 교체 후):"
echo "  qmrestore <백업파일경로> $VMID --storage <840pro-storage> --unique"
