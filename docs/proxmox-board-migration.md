# Proxmox 보드 이전 (7900X3D → Ryzen 3600 + X370 Pro)

## 하드웨어 구성

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| CPU/보드 | 7900X3D | Ryzen 3600 + ASUS Prime X370 Pro |
| GPU | RTX 3080 | GT 635 (키오스크 출력용) |
| NVMe | SN350 + 980 PRO + 990 PRO | SN350 (Proxmox OS)만 유지 |
| USB 오디오 | Onkyo | 제거 |
| 랜카드 | — | Intel I350-T2 듀얼포트 1G 추가 |

## PCIe 슬롯 배치

| 슬롯 | 장치 |
|------|------|
| x16_1 (3.0 x16) | GT 635 |
| x16_2 (3.0 x8) | LSI HBA (NAS VM 102 패스스루) |
| x16_3 (2.0 x4) | Intel I350-T2 |
| M.2 | WDC SN350 (Proxmox OS) |

## BIOS 확인사항

- 버전: 6232 (최신, 문제 구간 4602~5220 밖) → 업데이트 불필요
- IOMMU 활성화: BIOS → CPU Configuration 또는 AMD CBS → IOMMU 활성화

## X370 PCI Passthrough 특이사항

X370은 소비자용 칩셋이라 IOMMU 그룹이 한 덩어리로 묶임.
ACS Override 패치 필요:

```
GRUB: pcie_acs_override=downstream,multifunction
modprobe: options vfio_iommu_type1 allow_unsafe_interrupts=1
```

## VM 100 Windows 이전 계획

- 현재: win980 VG (980 PRO 1TB), 930GB thin, 실제 사용 ~170GB
- 목표: 840 PRO 256GB (SATA)에 복원
- 방법: vzdump 백업 → 보드 교체 후 840 PRO에 복원 (디스크 크기 축소)
- 불필요 프로그램 정리로 용량 추가 축소
- Windows 정품인증: VM UUID 유지되므로 재인증 불필요

## NAS SSD 캐시 변경

1. DSM에서 SSD 캐시 제거
2. 840 PRO 256GB x2 물리적 제거
3. 128GB x2 장착 후 캐시 재구성
4. 빠진 840 PRO 256GB: 1개 → VM 100 Windows 디스크, 1개 여분
