# Proxmox 보드 이전 절차 (7900X3D → Ryzen 3600 + X370 Pro)

## 교체 전 준비

```bash
# 1. /etc/pve/ 전체 백업
tar czf /root/pve-config-backup-$(date +%Y%m%d).tar.gz /etc/pve/

# 2. VM 설정 개별 백업
cp /etc/pve/qemu-server/*.conf /root/vm-conf-backup/

# 3. 네트워크 인터페이스 현황 기록
ip link show
cat /etc/network/interfaces
```

## 교체 후 체크리스트

- [ ] 네트워크 인터페이스 이름 재매핑 (`/etc/network/interfaces`)
- [ ] PCI 주소 변경 확인 (VM 설정의 `hostpci` 항목)
- [ ] CPU affinity 수정 (VM별 core 할당)
- [ ] LSI HBA 제거 후 SATA 포트 6개로 충분한지 확인
  - 840 PRO 2개 (구 캐시용 SSD) 제거 대상
- [ ] VM 100 Windows 정품인증: VM UUID 유지되므로 재인증 불필요

## 네트워크 재매핑 예시

```bash
# 구 보드 인터페이스가 enp5s0 였다면 신 보드에서 이름 확인
ip link show
# /etc/network/interfaces 에서 인터페이스명 교체
sed -i 's/enp5s0/NEW_IFACE/g' /etc/network/interfaces
systemctl restart networking
```

## 백업 복원 확인

```bash
tar tzf /root/pve-config-backup-*.tar.gz | head -20
```
