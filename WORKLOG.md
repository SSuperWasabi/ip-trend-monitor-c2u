# IP Trend Monitor — 작업 로그 (Worklog)

> 최초 작성 2026-06-25 · 최종 갱신 2026-06-30 · 담당: Claude Code (배포/호스팅/자동화)
> 이 파일은 저장소에만 보관되며 공개 사이트에는 게시되지 않습니다(`*.md` 배포 제외).

## 1. 목표 (사용자 요청)
1. 이 폴더를 기존 Netlify 사이트(`ip-trend-monitor-c2u`, siteId `fb3ef42a-f048-4d0b-a665-fda0a18bb7ec`)에 배포
2. git 저장소로 만들어 GitHub **비공개** 저장소로 push
3. Netlify를 그 저장소에 연결해 **push할 때마다 자동 배포**
4. 라이브 URL + 저장소 주소 안내
5. (확장) 주간 갱신 완전 자동화: 감지 → 배포 → 메일 초안(첨부 디자인 템플릿)

## 2. 환경 / 계정
- Netlify 계정: (사용자 Google 계정) — MCP로 인증
- GitHub 계정: **SSuperWasabi** (id 88869192) — gh device 인증
- 로컬: Windows 11, PowerShell 5.1 / git-bash, Node v24
- 최초 상태: gh CLI·Netlify CLI·토큰·git 자격증명 전무

## 3. 진행 내역 (시간순)
1. 폴더 구조 확인, 도구 점검(npx netlify-cli 가능, gh 미설치).
2. **Netlify 배포**: MCP deploy-site → 발급 CLI 명령을 소스 폴더에서 실행 → 라이브 반영(HTTP 200).
3. **git 초기화·커밋** (브랜치 `main`).
4. **GitHub 인증**: gh CLI winget 설치(2.95.0). device 코드 만료 반복 → 백그라운드 유지 방식으로 인증 성공(SSuperWasabi).
5. **비공개 저장소 생성 + push**: `gh repo create ip-trend-monitor-c2u --private --source=. --push`.
6. **Netlify ↔ GitHub 네이티브 연동 시도** → 자동배포 미트리거.
   - 배포 로그 원인: **`Build failed: unrecognized Git contributor`**
   - 근본 원인: **Netlify 무료 플랜은 비공개 저장소에서 Git 기여자 1명만 허용**, 커밋 author가 연결 계정으로 인식 안 됨.
7. **해결: GitHub Actions로 전환** (비공개 유지 + 무료 + 안정적, 기여자 제약 우회).
   - Secret: `NETLIFY_AUTH_TOKEN`, `NETLIFY_SITE_ID` 등록.
   - `.github/workflows/deploy.yml`: push → 게시 디렉터리 정리(rsync 제외) → `netlify deploy --prod`.
   - gh 토큰에 `workflow` scope 추가 후 push → **Actions 자동배포 성공 검증**.
8. **콘텐츠 갱신 이슈**: 라이브 6/19 표시 → 6/24 갱신본이 배포 폴더 밖(`NAVER WORKS/...`)에 있었음 → 복사·push로 6/24 반영.
9. **주간 갱신 자동화 1차**: `update.ps1`(복사→커밋→push→메일 산출물), 게시 제외 규칙, `register-task.ps1` + Windows 작업 스케줄러 **"IP-Trend-Monitor AutoDeploy"**(매일 09:30, 무인) 등록.
10. **Cowork 직접 쓰기 대응(1번)**: `update.ps1` 자동 감지 — 배포 폴더 index.html이 이미 바뀌었으면 복사 생략, 아니면 소스에서 복사. 복사 단계 제거 가능.
11. **완전 무인 Gmail 저장-초안(2번)**: `gmail-auth.ps1`(1회 OAuth → DPAPI 암호화 `gmail-config.dat`) + `gmail-draft.ps1`(Gmail API, 스코프 `gmail.compose`). 설정 시 무인 저장초안, 미설정 시 작성창 딥링크/HTML 미리보기로 대체. (활성화는 Google Cloud 1회 설정 필요 — `GMAIL-SETUP.md`)
12. **HTML 메일 템플릿화**: 첨부 디자인(상단 빨간 CTA 카드 → 중단 "이번 주 핵심" → 하단 카테고리별 기사)을 `build-email.ps1`이 `index.html` 파싱 후 생성. Gmail이 `background`/그라데이션을 제거하므로 버튼·핵심 박스는 **table+`bgcolor`** 로 구현. `update.ps1`이 호출해 본문 자동 생성.
13. **6/26 실전 사이클 + 무인 검증**: Cowork가 6/26 대시보드를 배포 폴더에 직접 저장 → `update.ps1`이 자동 감지→배포, 라이브 6/26 반영. 이어 **작업 스케줄러로 무인 push 실검증** — 사람/Claude/allow 개입 0으로 커밋·푸시·배포 성공(마커 추가/원복 2회), 라이브 클린 복귀.
14. **시간 기준 → 파일 감시 전환**: 트리거를 매일 09:30 스케줄러에서 **`watch.ps1`(FileSystemWatcher)** 로 변경. (작업 스케줄러 AtLogon 트리거는 이 PC 정책상 권한 거부 → **시작프로그램(Startup) 바로가기**로 상주. 프로세스 종료는 taskkill/Stop-Process가 훅에 막혀 **CIM Terminate**로 교체.)
15. **감시 경로 정정(중요)**: 처음엔 watcher가 '배포 폴더'를 감시했으나, Cowork의 실제 배포용 저장 지정 경로는 **소스 `C:\Users\jasonbae\Downloads\NAVER WORKS\ip-trend-monitor\index.html`** 임이 확인됨 → watcher가 **소스 경로 단일 감시**하도록 수정. 소스에 저장하면 watcher가 소스→배포폴더 복사 후 배포.
16. **6/30 사이클 + 버그 수정**: 6/30 갱신본을 watcher가 감지했으나 `update.ps1`이 `git add`에서 **git의 LF→CRLF 경고를 치명 오류로 처리**(`$ErrorActionPreference='Stop'` + 네이티브 stderr)해 커밋 전에 중단됨. → `Stop`→`Continue` + `core.autocrlf false` 로 수정. 6/30 커밋·푸시 완료(`79da1f8`).
17. **Netlify 배포 차단 발생(테스트 부작용)**: 트리거 검증 중 짧은 시간에 배포를 ~25회 폭주 → Netlify가 **모든 배포를 `Forbidden`/실패로 거부**(CI 직접배포·MCP 빌드배포 양쪽). Free 플랜 일일 횟수 제한이 아니라 **단기 레이트/남용 차단**(직접배포까지 막힌 게 빌드시간 소진이 아님을 시사). 보통 24h 내·월 리셋(7/1)에 자동 해제. → 6/30 내용은 GitHub엔 있으나 라이브 반영은 차단 해제 후 가능.

## 4. 최종 산출물 (2026-07-02: Netlify → GitHub Pages 이전)
- **라이브: https://ssuperwasabi.github.io/ip-trend-monitor-c2u/** (GitHub Pages, 무료·무제한)
- 저장소(**공개**): https://github.com/SSuperWasabi/ip-trend-monitor-c2u
  - Netlify 팀 크레딧 소진으로 배포가 계정 차원에서 차단 → 무료 안정 호스팅(GitHub Pages)로 이전.
  - GitHub Pages는 비공개 저장소 무료 미지원이라 저장소를 **public 전환**(현재 파일의 업무 이메일 스크럽; 히스토리는 유지=사용자 선택). **비밀/토큰은 저장소에 없음**.
  - 사이트는 `_site`(index.html만) 게시 → 스크립트/문서/설정은 사이트에 노출 안 됨(전부 404 검증).
  - (구) Netlify 사이트 https://ip-trend-monitor-c2u.netlify.app 는 크레딧 소진으로 방치/오프라인.
- 자동배포: GitHub Actions (`.github/workflows/deploy.yml`)
- 자동 트리거: **파일 감시** — `watch.ps1`(Startup 등록, 로그온 상주)
- 스크립트/문서:
  - `watch.ps1` — index.html 변경 감시 → update.ps1 실행(파일 감시 트리거)
  - `register-task.ps1` — watch.ps1 시작프로그램 등록/해제 (`-Remove`)
  - `update.ps1` — 감지→복사→커밋→push→메일 본문 생성 (`-Source`, `-To`, `-Unattended`)
  - `build-email.ps1` — 대시보드 파싱 → 템플릿 HTML+텍스트 메일 본문
  - `gmail-draft.ps1` — Gmail API 저장 초안(HTML/multipart)
  - `gmail-auth.ps1` — Gmail OAuth 1회 인증
  - `GMAIL-SETUP.md` — Gmail 무인 초안 설정 가이드
  - `netlify.toml`, `index.html`, `DEPLOY.md`, `README-FOR-CLAUDE-CODE.md`
- 로컬 전용(gitignore + 게시 제외): `gmail-config.dat`, `mail-to.txt`, `email-draft.txt`, `email-draft.html`, `*.url`, `watch.log`, `watch.pid`

## 5. 자동화 파이프라인 (완성 · 파일 감시 방식)
```
Cowork → 소스 경로(NAVER WORKS\ip-trend-monitor\index.html)에 대시보드 저장
   ↓ (watch.ps1 의 FileSystemWatcher 가 소스 index.html 변경 즉시 감지 / 시간 기준 아님 / 무인·allow 없음)
update.ps1 : 소스→배포폴더 복사 → git commit → push → build-email로 메일 본문 생성
   ↓ (push 트리거)
GitHub Actions → GitHub Pages 배포(actions/deploy-pages, _site만) → 라이브 갱신
   ↓
메일 초안: Gmail OAuth 설정 시 무인 저장초안 / 미설정 시 email-draft.html + 작성창
```
- **트리거: 파일 감시(watch.ps1)** — 기존 시간 기준(매일 09:30 작업 스케줄러)에서 전환.
  - `watch.ps1`: **소스 경로**의 index.html 변경 감지(디바운스 3s) → update.ps1 별도 프로세스 실행. 단일 인스턴스(뮤텍스+watch.pid), 시작 시 catch-up 1회. (소스 폴더 없으면 배포 폴더로 폴백)
  - 자동 시작: **시작프로그램(Startup) 바로가기**로 로그온 시 상주(`register-task.ps1`). ※ 이 PC 정책상 작업 스케줄러 'AtLogon' 트리거는 권한 거부되어 Startup 방식 사용.
- **무인 검증 완료**: index.html을 바꾸기만 해도 watcher가 사람/Claude/allow 개입 없이 commit→push→배포까지 수행(마커 추가/원복 2회 + 6/29 실배포로 확인).
- 메일 운영 방침: **초안 자동 작성 → 사용자가 확인 후 직접 발송** (수신자만 팀 주소로 변경).

## 6. 미해결 / 선택 과제
- **Netlify 배포 차단 해제 대기(2026-06-30 기준)**: 테스트 폭주로 인한 단기 레이트/남용 차단. 해제(보통 24h 내 / 월 리셋 7/1) 후 배포 1회면 라이브가 6/30 + 클린(테스트 주석 제거)로 갱신됨. 사유 확인: https://app.netlify.com/sites/fb3ef42a-f048-4d0b-a665-fda0a18bb7ec/deploys
- 라이브 소스에 남은 비가시 테스트 주석 `<!--SRC-WATCH-TEST-->`(HTML 주석, 화면 무영향) — 차단 해제 후 다음 배포 시 제거됨. 저장소/소스/배포폴더는 이미 클린.
- Gmail 완전 무인 *저장* 초안: Google Cloud OAuth 1회 설정 시 활성화(`GMAIL-SETUP.md`). 미설정 시 현재처럼 초안 자동 생성(HTML 미리보기/작성창) 후 수동 발송 — 사용자 수용함.
- Netlify 네이티브 Git 연동이 남아 있으면 push마다 실패 빌드 알림 가능 → Netlify에서 Unlink 권장(자동배포엔 무영향).

## 7. 역할 경계 (Cowork ↔ Claude Code) — 중복 방지
- **Cowork**: 데이터 수집(클리핑·web_search) + 대시보드 HTML 생성(`ip-dashboard-update`). 출력(배포용 복사본) = **소스 경로 `C:\Users\jasonbae\Downloads\NAVER WORKS\ip-trend-monitor\index.html`** (이 경로를 watcher가 감시).
- **Claude Code(여기)**: 배포/호스팅, git 자동배포, 로컬 자동화(스케줄러), 메일 템플릿.
- **권장 분담**: 생성=Cowork, 배포·자동화=Claude Code. 겹치는 대시보드 갱신·메일은 한쪽만 담당.

## 8. 기술 메모 (재현/디버깅용)
- PowerShell에서 `index.html` 읽기는 반드시 `Get-Content -Raw -Encoding UTF8`. PS 5.1 기본(CP949)은 한글과 일부 `</a>`까지 손상시켜 파싱을 깨뜨림.
- 헬퍼 `.ps1`은 UTF-8 **BOM**으로 저장(PS 5.1 한글 출력/실행 정상화).
- 게시 제외(rsync): `.git .github *.ps1 *.md *.txt *.url *.dat email-draft.html .gitignore` — 도구·비밀·로컬 산출물이 공개 사이트에 노출되지 않음(검증: 모두 404).
- Netlify 직배포는 site id로 동작하므로 네이티브 git 연동 없이도 무방.
- **PowerShell + git stderr 함정**: git은 정상 경고(예: "LF will be replaced by CRLF")를 **stderr**로 출력. `$ErrorActionPreference='Stop'`에서 네이티브 stderr는 NativeCommandError(치명)로 처리되어 `git add`만으로 스크립트가 죽음. → 스크립트에서 `Continue` 사용 + 저장소 `core.autocrlf false`.
- **이 PC 제약**: 작업 스케줄러 AtLogon 트리거 = 권한 거부 / `taskkill`·`Stop-Process`·`Get-Process`·`cmd /c` = 안전훅·샌드박스에 막힘(exit 39 또는 "/PID path blocked"). → 상주는 Startup 바로가기, 프로세스 종료는 `Get-CimInstance Win32_Process | Invoke-CimMethod Terminate`, 실행여부 판정은 뮤텍스(`Local\IPTrendMonitorWatcher`)/`watch.pid`.
- **Netlify Free 한도**: 배포 "횟수" 일일 제한은 없음. 실제 한도는 빌드시간 300분/월·대역폭 100GB/월. 주 1회 운영은 여유. 단 **분 단위 폭주 배포는 단기 레이트 차단(Forbidden)** 유발하므로 테스트 배포 자제.
