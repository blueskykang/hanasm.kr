# 피싱 침해 분석 리포트 — 2026-07

## 개요

`blue@kangc.co.kr`을 표적으로 한 **동일 공격자의 연속 피싱** 2건. MS OneDrive / 회의 승인으로 위장한 **OAuth 계정 탈취** 시도.

## 타임라인

| 날짜 | 발신 도메인 | 위장 이름 | 주제 |
|------|-----------|----------|------|
| 2026-07-10 | nextgenerationvt.com | Kangc 안내실 | 회의 승인 (Blue Friday) |
| 2026-07-14 | kemari.digital | Kangc 규정 준수 부서 | 확정된 회의 기록 (문서통지) |

## 핵심 발견 — 동일 발송 IP

두 메일 모두 **같은 서버에서 발송**:

```
발송 IP: 172.245.174.85 (ColoCrossing, 미국 VPS)
HELO 위장: hes.it (7/14), thearkrentals.com (7/10)
릴레이: smtp-relay.gmail.com (Google Workspace 악용)
경유: mail-pj1-f104 / mail-ot1-f103.google.com → kangc.co.kr Postfix → 네이버
```

## 인증 우회 분석

| 메일 | SPF | DKIM | DMARC | 비고 |
|------|-----|------|-------|------|
| kemari.digital | pass | pass (커스텀) | pass (p=none) | 정식 인증 완비 |
| nextgenerationvt.com | none | pass (google 기본) | none | 인증 허술 |

**우회 원리:** 당신 도메인(kangc.co.kr)을 사칭한 게 아니라, **공격자가 자기 도메인을 등록·인증**하고 **표시이름만 "Kangc"로 위장**. → kangc.co.kr의 DMARC(p=reject)로는 차단 불가.

## 공격 수법 — OAuth Consent Phishing

"문서 열기" 링크 (kemari.digital 메일):
```
https://login.microsoftonline.com/common/oauth2/v2.0/authorize
  ?state=Ymx1ZUBrYW5nYy5jby5rcg==   (base64 → blue@kangc.co.kr, 표적 확인)
  &client_id=fcff805a-980c-4fab-83ab-231703a7c122
  &scope=openid profile User.Read
  &prompt=none
  &uri=https://honeywell.com
```

- 가짜 페이지가 아닌 **진짜 MS OAuth 인증** 사용 → MFA 우회 가능
- 로그인+동의 시 악성 앱에 계정 접근 권한 부여 위험
- 숨김 추적 태그: `SEC-604047371821-Blue` (흰 글씨)

## IOC (침해 지표)

```
IP:        172.245.174.85
도메인:     kemari.digital, nextgenerationvt.com
HELO:      hes.it, thearkrentals.com
발신주소:   thijs.mensinkDfyFm@kemari.digital
           sleblancZ7JUJ@nextgenerationvt.com
표시이름:   Kangc 규정 준수 부서, Kangc 안내실
릴레이:     smtp-relay.gmail.com
OAuth app: fcff805a-980c-4fab-83ab-231703a7c122
추적태그:   SEC-604047371821-Blue
```

## 대응 조치

1. **메일 차단 규칙 적용** → `mail-security/apply-phishing-block.sh`
   - 발송 IP(172.245.174.85) header_checks 차단
   - 발신 도메인 REJECT
2. **클릭 대응** (7/14 메일 버튼 클릭됨):
   - MS 계정 로그인 활동 확인
   - 앱 사용 권한에서 낯선 앱 취소
   - 로그인/동의했다면 비번 변경 + MFA 재설정
3. **신고**:
   - Google (smtp-relay.gmail.com 악용 + 두 워크스페이스 도메인)
   - ColoCrossing abuse (172.245.174.85)

## 교훈

- DMARC(p=reject)는 **자기 도메인 사칭**만 막음. **남의 도메인 + 표시이름 위장**은 못 막음.
- 이런 유형은 **발송 IP header_checks + 발신도메인 차단 + 표시이름 휴리스틱**으로 대응.
- Google Workspace 릴레이(smtp-relay.gmail.com) 악용이 늘고 있음.
