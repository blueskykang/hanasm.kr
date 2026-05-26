# 백업 계획 (VM 102 → VM 210)

## 구성

| 항목 | 내용 |
|------|------|
| 백업 대상 | VM 102 (BlueNasHome) |
| 백업 서버 | VM 210 헤놀로지 (4TB + 6TB = 10TB) |
| 현재 NAS 사용량 | 7.1TB |
| 백업 방식 1 | Hyper Backup (DSM → 210 동기화) |
| 백업 방식 2 | Proxmox `vzdump` → 210 저장 |

## 진행 순서 (210 파워 ON 후)

```bash
# 1. Proxmox에서 210 접속 확인
ping <VM210_IP>

# 2. vzdump 백업 디렉터리를 210 마운트 포인트로 설정
# /etc/pve/storage.cfg 에 NFS/SMB 스토리지 추가 예시:
# nfs: backup-210
#   export /volume1/proxmox-backup
#   path /mnt/pve/backup-210
#   server <VM210_IP>
#   content backup

# 3. 테스트 백업 실행
vzdump 102 --storage backup-210 --compress zstd --mode snapshot
```

## Hyper Backup 설정 (DSM)

1. 패키지 센터 → Hyper Backup 설치
2. 백업 작업 → 원격 NAS (210 IP)
3. 대상 폴더 선택 → 스케줄 설정 (매일 새벽 2시)
4. 보존 정책: 7일 일별, 4주 주별
