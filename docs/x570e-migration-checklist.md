# X570-E 교체 확정 체크리스트 (실제 구성 기준)

> 2026-07-15 기록된 실제 prox 구성 기반. X370-Pro → X570-E, CPU는 3600 유지.
> 백업 위치: `/root/x570e-migration-20260715/`

## 현재 구성 (교체 전 확정값)

| 장치 | 현재 PCI | 현재 이름 | MAC | 역할 |
|------|---------|----------|-----|------|
| I350-T2 포트1 | 04:00.0 | enp4s0f0 | 48:df:37:55:80:2a | bond0 슬레이브 |
| I350-T2 포트2 | 04:00.1 | enp4s0f1 | 48:df:37:55:80:2a | bond0 슬레이브 |
| 온보드 I211 | 08:00.0 | enp8s0 | 60:45:cb:9f:49:38 | vmbr2 (10.20.0.1) |
| LSI HBA SAS3008 | **0b:00.0** | — | — | VM 102 패스스루 |
| AMD RX550 Lexa | 0a:00.0 | — | — | 호스트 콘솔 |

**네트워크 논리 구성:**
```
bond0 (LACP 802.3ad) = enp4s0f0 + enp4s0f1 (I350-T2)
  └ vmbr0 = 192.168.219.50/24 (메인랜, 게이트웨이 .1)
enp8s0 (I211)
  └ vmbr2 = 10.20.0.1/24 (내부망)
```
⚠️ vmbr0의 iptables NAT 규칙(tailscale→RDP 53389 포워딩) 있음 — interfaces에 포함, 유지됨.

**GRUB (교체 시 변경 금지, 그대로 유지):**
```
quiet pcie_acs_override=downstream,multifunction amd_iommu=on iommu=pt
kvm-amd.avic=0 kvm-amd.npt=1 kvm-amd.nested=1 iommufd=on
iommu.passthrough=1 vfio-pci.ids=1000:0097
```
- `vfio-pci.ids=1000:0097` = LSI를 ID로 바인딩 → 주소 바뀌어도 유지됨 ✅
- ACS override = 첫 부팅은 그대로 유지 (X570 정리는 나중에)

## 교체 절차

### ① 종료 (SSH/Shell)
```bash
for v in 100 101 102; do qm shutdown $v --timeout 120; done
qm list          # 모두 stopped 확인
shutdown -h now
```

### ② 물리 교체
```
- 보드: X370-Pro → X570-E
- 이설: SN350 NVMe, RAM, 3600 CPU, LSI HBA, I350-T2, AMD RX550
- 슬롯 권장:
    PCIEX16_1 (x16) → (비움, 나중 GTX 1650)
    PCIEX16_2 (x8)  → LSI HBA
    PCIEX16_3 (x4)  → AMD RX550 (호스트 콘솔)
    I350-T2         → 남는 x16/x1 슬롯 아무 곳 (대역폭 무관)
```

### ③ BIOS (Del)
```
Advanced → SVM Mode = Enabled
Advanced → IOMMU = Enabled
Boot → 1순위 = SN350 NVMe
(절전 원하면) APM → Power On By RTC = 07:50
```

### ④ 첫 부팅 후 — ⚠️ AMD RX550 모니터 + 키보드로

NIC 이름이 바뀌어 네트워크·SSH 끊김. 콘솔에서:

```bash
# 1) 새 NIC 이름·MAC 확인
ip -br link show
```

**MAC으로 매칭:**
- `48:df:37:55:80:2a` 두 개 → I350-T2 → bond0 슬레이브
- 새 MAC (60:45:cb 아님) → X570-E 온보드 → vmbr2

```bash
# 2) interfaces 수정
nano /etc/network/interfaces
#   bond-slaves <신규I350포트1> <신규I350포트2>
#   (enp8s0 → 새 온보드 이름으로)  vmbr2의 bridge-ports
systemctl restart networking      # 네트워크 복구
ping 192.168.219.1                 # 게이트웨이 확인
```

```bash
# 3) HBA 패스스루 주소 갱신
lspci -nn | grep -i LSI            # 새 주소 확인 (예 0c:00.0)
nano /etc/pve/qemu-server/102.conf
#   hostpci0: 0000:0b:00.0,pcie=1,rombar=0
#   → hostpci0: 0000:<새주소>,pcie=1,rombar=0
```

### ⑤ 검증
```bash
qm start 102 && sleep 30 && qm status 102     # NAS + HBA 패스스루
qm start 100; qm start 101
ip -br addr show vmbr0 vmbr2                   # 192.168.219.50 / 10.20.0.1
# 메일·캘린더·서비스 확인
```

## 되돌리기 / 문제 시

- 네트워크 복구 실패 → `cat /root/x570e-migration-20260715/interfaces.old` 참고
- HBA 패스스루 실패 → IOMMU 그룹 확인, 필요시 ACS override 유지(이미 있음)
- 설정 전체 복구 → `/root/x570e-migration-20260715/pve-etc.tar.gz`

## 나중에 (선택, 안정화 후)
- X570 IOMMU 확인 후 GRUB에서 `pcie_acs_override=downstream,multifunction` 제거 시도
- GTX 1650 추가 → PCIEX16_1 → 에뮬 VM 패스스루
- 야간 절전 (`scripts/power-schedule-setup.sh`)
