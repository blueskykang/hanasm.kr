# 🚨 피싱 경보 전파 — 타 관리 서버/관리자 공유용

> 2026-07, blue@kangc.co.kr 표적 피싱 2건 탐지. 동일 공격자가 도메인을 바꿔가며
> "Kangc" 사칭 + MS OAuth 계정 탈취를 시도 중. 아래 내용 각 서버에 전파·차단 요망.

## 즉시 차단 대상 (IOC)

```
발송 IP:    172.245.174.85            ← 최우선 차단
발신 도메인: kemari.digital
            nextgenerationvt.com
HELO:       hes.it, thearkrentals.com
릴레이:      smtp-relay.gmail.com (Google Workspace 악용)
표시이름:    "Kangc 규정 준수 부서", "Kangc 안내실"
OAuth app:  fcff805a-980c-4fab-83ab-231703a7c122
추적태그:    SEC-604047371821-Blue
```

## 특징 (관리자 숙지)

- **정상 인증 통과**: 공격자가 자기 도메인을 SPF/DKIM/DMARC 정식 설정 → 인증 필터로 안 걸림
- **위장 방식**: 도메인은 남의 것, **표시이름만 "Kangc"** → 내부 메일처럼 보임
- **DMARC 무력**: kangc.co.kr 사칭이 아니라 남의 도메인이라 우리 DMARC로 차단 불가
- **진짜 MS OAuth 사용**: 가짜 페이지 아님 → MFA도 우회 가능, 매우 위험

## 각 서버 차단 방법

### Postfix 계열
```
# header_checks (pcre) — 발송 IP 차단
/^Received:.*\[172\.245\.174\.85\]/   REJECT phishing source

# sender_access — 도메인 차단
kemari.digital          REJECT
nextgenerationvt.com    REJECT
```

### 메일 게이트웨이 / 스팸필터 (일반)
- 발신 도메인 kemari.digital, nextgenerationvt.com → 블랙리스트
- 본문 내 `login.microsoftonline.com/...client_id=fcff805a-...` 링크 → 격리
- 표시이름 "Kangc" + From 도메인 ≠ kangc.co.kr → 격리/경고

## 사용자 공지 문구 (그대로 전달 가능)

> [보안 공지] "Kangc"를 사칭한 피싱 메일이 유포되고 있습니다.
> "문서통지 / 회의 승인 / OneDrive 보안 파일" 등의 제목으로 오며,
> 발신 주소가 kangc.co.kr이 아닌 외부 도메인입니다.
> 본문의 "문서 열기" 버튼을 **절대 클릭하지 마시고**, 클릭·로그인하셨다면
> 즉시 비밀번호를 변경하고 관리자에게 알려주세요.

## 클릭·유출 시 대응

1. MS 계정 → 로그인 활동 확인 (낯선 접속)
2. 앱 사용 권한 → 낯선 앱 권한 취소
3. 비밀번호 변경 + MFA 재설정
4. 관리자 통보

## 신고 채널

- Google: smtp-relay.gmail.com 악용 + 두 워크스페이스 도메인 신고
- ColoCrossing: abuse@colocrossing.com (172.245.174.85)

---
*상세 분석: `docs/phishing-incident-2026-07.md` · 차단 적용: `mail-security/apply-phishing-block.sh`*
