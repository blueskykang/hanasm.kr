# Proxmox 보드 교체 — X370-Pro → ASUS ROG STRIX X570-E GAMING

## 개요

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 보드 | ASUS Prime X370-Pro | ASUS ROG STRIX X570-E GAMING |
| CPU | Ryzen 3600 | 3600 유지 **또는** 5900X (선택) |
| 온보드 랜 | Intel I211 (1개) | Realtek 2.5G + Intel 1G (**2개**) |
| IOMMU | ACS override 필요 | **네이티브 분리 (override 불필요)** |
| PCIe | 3.0 | 4.0 |

**핵심 이점:** X570-E는 IOMMU 그룹이 깔끔해서 X370에서 쓰던 `pcie_acs_override` 패치를 **제거**할 수 있고, 온보드 랜이 2개라 **I350-T2 듀얼랜 제거 가능**.

## 슬롯 배치 (확정)

| 슬롯 | 속도 | 장치 |
|------|------|------|
| PCIEX16_1 | 4.0 x16(or x8) | GTX 1650 (에뮬 VM) *또는 비움* |
| PCIEX16_2 | 4.0 x8 | LSI HBA (NAS VM 102) |
| PCIEX16_3 | 4.0 x4 | GT 635 (호스트 콘솔) |
| 온보드 | — | Realtek 2.5G + Intel 1G |

> 참고: PCIEX16_3(x4)는 PCIEX1_2와 대역폭 공유. GT 635는 x4로 충분.

## ⚠️ 교체 전 반드시

1. `/etc/pve` 전체 백업
2. 현재 NIC 이름·PCI 주소·IOMMU 그룹 기록
3. **GT 635 + 키보드 준비** — 교체 후 NIC 이름 바뀌어 SSH 끊김. 물리 콘솔 필수.

## 작업 순서

### 1단계 — 교체 전 (SSH, `x570e-pre-migration.sh` 실행)
- 설정 백업, NIC/PCI/IOMMU 현황 기록

### 2단계 — 물리 교체
```
1. VM 정상 종료 → 호스트 셧다운
2. 보드 교체 (X370-Pro → X570-E)
   - 이설: SN350 NVMe, RAM, LSI HBA, GT 635, (GTX 1650)
   - CPU: 3600 그대로 또는 5900X 장착
3. BIOS 설정:
   - SVM Mode = Enabled (가상화)
   - IOMMU = Enabled
   - (전력절감 원하면) APM → Power On By RTC = 07:50
   - Boot Order → SN350 NVMe
   - 5900X 장착 시: BIOS 최신인지 확인 (X570-E는 Zen3 네이티브 지원)
```

### 3단계 — 교체 후 (⚠️ GT 635 콘솔, `x570e-post-migration.sh` 실행)
- NIC 이름 재매핑 (`/etc/network/interfaces`)
- ACS override 제거 (X570은 불필요)
- 패스스루 PCI 주소 재매핑 (HBA, GPU)
- IOMMU 그룹 재확인
- update-grub / update-initramfs

### 4단계 — 검증
- VM 100/101/102 부팅
- NAS HBA 패스스루 정상 확인
- 네트워크·메일·캘린더 서비스 확인

## 주의사항

- **VM 100 Windows 정품인증**: VM UUID 유지 → 재인증 불필요
- **NIC 이름**: X570-E는 온보드 2개 → `enpXs0`(2.5G), `enpYs0`(1G) 형태. 실제 이름은 교체 후 `ip link`로 확인
- **ACS override 제거**: 제거 후 IOMMU 그룹이 잘 분리됐는지 확인 필수. 만약 GPU/HBA가 같은 그룹에 묶이면 다시 추가
- **5900X 선택 시**: 전력 상시 +~30W (누진 3단계 기준 월 +약 1만원). 3600 유지도 X570-E에서 문제없음.
