# hanasm.kr — Proxmox 홈서버 관리

## 서버 구성 현황

| 역할 | 호스트 | 접속 |
|------|--------|------|
| Proxmox 호스트 | 180.229.224.19 | `ssh -p 8007 root@180.229.224.19` |
| VM 102 (BlueNasHome) | NAS (DSM) | SSH 터널 경유 |
| VM 210 (백업서버) | 헤놀로지 4TB+6TB | 파워 ON 후 설정 예정 |

## VM 목록

| VMID | 이름 | 상태 |
|------|------|------|
| 100 | Windows11 | stopped |
| 101 | LinuxServer | stopped |
| 102 | BlueNasHome | running |

## 미완료 작업

- [ ] PhpStorm → NAS MariaDB SSH 터널 접속 (47330 → 127.0.0.1:3306)
- [ ] 210 백업서버 설정 (파워 ON 후 vzdump + Hyper Backup 구성)
- [ ] 보드 이전 실행 (7900X3D → Ryzen 3600 + X370 Pro)
- [ ] NAS 잔여 작업: WebFile 복원, SSD 캐시, 패키지 재설치
