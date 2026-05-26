# PhpStorm → NAS MariaDB SSH 터널 접속 (미해결)

## 현황

- MariaDB 10 포트 3306 TCP 리스닝 활성화 완료
- `blueskykang@%` 원격 접속 권한 등록 완료
- SSH 터널 포트: 47330 → 127.0.0.1:3306

## PhpStorm 설정 방법

1. **Database** 탭 → **+** → **MariaDB**
2. **SSH/SSL** 탭:
   - SSH tunnel 체크
   - Proxy host: `180.229.224.19`
   - Proxy port: `8007`
   - Proxy user: `root` (또는 blueskykang)
   - Auth type: Key pair
3. **General** 탭:
   - Host: `127.0.0.1`
   - Port: `3306`
   - User: `blueskykang`
   - Password: (설정된 비밀번호)

## 트러블슈팅

SSH MaxAuthTries 원복 완료 (`#MaxAuthTries 6`).

DSM 방화벽에서 내부 IP 대역 → 3306 허용 여부 확인 필요:
```
제어판 → 보안 → 방화벽 → 규칙 편집
```

VM 102에서 직접 확인:
```bash
ss -tlnp | grep 3306
mysql -u blueskykang -p -h 127.0.0.1
```

Proxmox 호스트에서 VM 102 IP로 포트 확인:
```bash
nc -zv <VM102_IP> 3306
```
