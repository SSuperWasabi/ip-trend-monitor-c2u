# Gmail 무인 저장-초안 설정 (1회성)

`update.ps1` 이 무인으로 *실제 Gmail 저장 초안*을 만들려면, Gmail API OAuth를 1회 설정해야 합니다.
설정 후에는 매주 자동(스케줄러)으로 라이브 링크가 담긴 초안이 임시보관함에 생성됩니다.

> 안 해도 됩니다. 미설정 시 `update.ps1` 은 `메일-초안-열기.url`(작성창 딥링크)을 대신 만듭니다.

## A. Google Cloud Console (브라우저, 1회)
1. https://console.cloud.google.com 접속 → 상단에서 **프로젝트 만들기**(예: `ip-trend-mailer`).
2. **API 및 서비스 → 라이브러리** → "Gmail API" 검색 → **사용 설정**.
3. **API 및 서비스 → OAuth 동의 화면**:
   - User type: **내부(Internal)** 선택 (com2us.com 조직 계정이면 가능 → 검수 불필요).
   - 앱 이름/지원 이메일만 채우고 저장.
   - (Internal 선택이 안 되면 External + 테스트 사용자에 본인 메일 추가)
4. **API 및 서비스 → 사용자 인증 정보 → 사용자 인증 정보 만들기 → OAuth 클라이언트 ID**:
   - 애플리케이션 유형: **데스크톱 앱**.
   - 생성 후 **클라이언트 ID** 와 **클라이언트 보안 비밀** 을 복사.

## B. 로컬 1회 인증 (이 폴더에서)
```powershell
powershell -ExecutionPolicy Bypass -File .\gmail-auth.ps1 -ClientId "복사한_클라이언트ID" -ClientSecret "복사한_보안비밀"
```
- 브라우저 동의 화면이 뜨면 **본인 com2us 메일**로 허용.
- 성공 시 `gmail-config.dat`(DPAPI 암호화) 가 생성됩니다. 이 파일은 git에 올라가지 않습니다.

## C. (선택) 수신자 지정
- `mail-to.txt` 파일을 만들고 팀 배포 주소를 줄/쉼표로 적으면 초안 수신자로 사용됩니다.
- 없으면 기본 수신자는 본인(jasonbae@com2us.com). 발송 전 변경하세요.

## 확인
```powershell
powershell -ExecutionPolicy Bypass -File .\gmail-draft.ps1 -To "jasonbae@com2us.com" -Subject "테스트 초안" -Body "본문 테스트"
```
→ Gmail 임시보관함에 초안이 생기면 성공. 이후 `update.ps1` 이 자동으로 초안을 만듭니다.

## 보안 메모
- `gmail-config.dat` 는 현재 Windows 사용자 계정에서만 복호화됩니다(DPAPI).
- 스코프는 `gmail.compose`(초안 생성 전용)로 최소화되어 메일 읽기/발송 권한은 없습니다.
- 권한 취소: https://myaccount.google.com/permissions
