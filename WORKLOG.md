# IP Trend Monitor — 작업 로그 (Worklog)

> 작성: 2026-06-25 · 담당: Claude Code (배포/호스팅/자동화)
> 이 파일은 저장소에만 보관되며 공개 사이트에는 게시되지 않습니다(`*.md` 배포 제외).

## 1. 목표 (사용자 요청)
1. 이 폴더를 기존 Netlify 사이트(`ip-trend-monitor-c2u`, siteId `fb3ef42a-f048-4d0b-a665-fda0a18bb7ec`)에 배포
2. git 저장소로 만들어 GitHub **비공개** 저장소로 push
3. Netlify를 그 저장소에 연결해 **push할 때마다 자동 배포**
4. 라이브 URL + 저장소 주소 안내
5. (확장) 주간 갱신 흐름 자동화: 감지 → 배포 → Gmail 초안

## 2. 환경/계정
- Netlify 계정: jasonbae@com2us.com (Google 로그인) — MCP로 인증됨
- GitHub 계정: **SSuperWasabi** (id 88869192, 이메일 비공개)
- 로컬: Windows 11, PowerShell 5.1 / git-bash, Node v24
- 최초 상태: gh CLI·Netlify CLI·토큰·git 자격증명 모두 없음

## 3. 진행 내역 (시간순)
1. 폴더 구조 확인(`netlify-deploy/`: index.html, netlify.toml, 문서). 도구 확인 → npx로 netlify-cli 사용 가능, gh 미설치.
2. **Netlify 배포**: MCP로 deploy-site 호출 → 발급된 CLI 명령을 소스 폴더에서 실행 → 라이브 반영(HTTP 200).
3. **git 초기화·커밋** (브랜치 `main`).
4. **GitHub 인증**: gh CLI를 winget으로 설치(2.95.0). device 코드 흐름이 만료로 수차례 실패 후, 백그라운드 유지 방식으로 인증 성공(SSuperWasabi).
5. **비공개 저장소 생성 + push**: `gh repo create ... --private --source=. --push`.
6. **Netlify ↔ GitHub 네이티브 연동 시도** → 자동배포가 트리거되지 않음.
   - 진단: push마다 커밋 상태/새 배포 0건. 빌드는 Active.
   - 사용자 재연결 후 배포 로그에서 원인 확인: **`Build failed: unrecognized Git contributor`**
   - 근본 원인: **Netlify 무료 플랜은 비공개 저장소에서 Git 기여자 1명만 허용**. 커밋 author(jasonbae@com2us.com)가 연결된 GitHub 계정(SSuperWasabi)으로 인식되지 않아 빌드 거부.
7. **해결: GitHub Actions로 전환** (비공개 유지 + 무료 + 안정적, 기여자 제약 우회).
   - GitHub Secret 등록: `NETLIFY_AUTH_TOKEN`, `NETLIFY_SITE_ID`
   - `.github/workflows/deploy.yml` 추가(push→빌드 디렉터리 정리→`netlify deploy --prod`).
   - gh 토큰에 `workflow` scope 추가(재인증) 후 push → **Actions 자동배포 성공 검증**.
8. **콘텐츠 갱신 이슈**: 라이브가 6/19로 표시됨 → 6/24 갱신본이 배포 폴더 밖(`NAVER WORKS/ip-trend-monitor/index.html`)에 있었음. 6/24본을 배포 폴더로 복사·push → 라이브 6/24 반영 확인.
9. **주간 갱신 자동화 구축**:
   - `update.ps1`: 소스 index.html 복사 → 변경 시 커밋·push → Gmail 초안 산출물 생성.
   - 배포 게시에서 비공개/메타 파일 제외(`*.ps1 *.md *.txt *.url .gitignore .git .github`). 로컬 산출물 gitignore.
   - `register-task.ps1` + Windows 작업 스케줄러 **"IP-Trend-Monitor AutoDeploy"**(매일 09:30, 무인) 등록·실행 검증(결과 0).
   - **이번 주 실제 Gmail 초안 생성**(Claude Gmail 연동).

## 4. 최종 산출물
- 라이브: https://ip-trend-monitor-c2u.netlify.app (현재 2026-06-24)
- 저장소(비공개): https://github.com/SSuperWasabi/ip-trend-monitor-c2u
- 자동배포: GitHub Actions (`.github/workflows/deploy.yml`)
- 헬퍼: `update.ps1`, `register-task.ps1`
- 스케줄 작업: "IP-Trend-Monitor AutoDeploy" (매일 09:30)

## 5. 미해결/선택 과제
- 완전 무인 *저장된* Gmail 초안: 일반 스크립트가 Claude Gmail 연동을 못 부르므로 Gmail API OAuth 1회 셋업 필요(미구축). 현재는 작성창 딥링크(`메일-초안-열기.url`)로 대체.
- Netlify 네이티브 Git 연동이 남아 있으면 push마다 실패 빌드 알림 발생 가능 → Netlify에서 Unlink 권장(자동배포엔 영향 없음).
- Gmail 수신자(팀 배포 주소) 미지정 → 초안 기본 수신자는 본인. 발송 전 변경.

## 6-1. (추가) HTML 메일 템플릿 자동화
- 첨부 디자인(상단 빨간 CTA 카드 → 중단 "이번 주 핵심" → 하단 카테고리별 기사)을 템플릿화.
- `build-email.ps1`: `index.html`을 파싱(데이터 추출) → 승인된 HTML(이메일 표준 table+bgcolor) + 텍스트 본문 생성.
  - Gmail이 `background`/그라데이션을 제거하므로 빨간 버튼·핵심 박스는 `bgcolor` 속성으로 구현.
- `gmail-draft.ps1 -HtmlBody`: multipart/alternative(텍스트+HTML)로 실제 저장 초안 생성.
- `update.ps1`이 build-email 호출 → Gmail 설정 시 무인 HTML 초안, 미설정 시 email-draft.html 미리보기 + 작성창.
- 함정/교훈: PowerShell에서 index.html을 읽을 땐 반드시 `-Encoding UTF8` (기본 CP949가 한글·일부 `</a>`까지 손상시켜 파싱 실패의 원인이었음). 헬퍼 .ps1은 모두 UTF-8 BOM 저장.

## 6. 역할 경계 (Cowork ↔ Claude Code) — 중복 방지
- **Cowork**: 데이터 수집(클리핑·web_search 커넥터) + 대시보드 HTML 생성(`ip-dashboard-update`). 산출물 = `NAVER WORKS/ip-trend-monitor/index.html`.
- **Claude Code(여기)**: 배포/호스팅, git 자동배포, 로컬 자동화(스케줄러), 그리고 필요 시 Gmail 초안 생성.
- **권장 분담**: *생성=Cowork, 배포·자동화=Claude Code*. 겹치는 지점(대시보드 갱신·메일 초안)은 한쪽만 맡기기. 예) Cowork가 생성까지만 하고, 이후 감지→배포→메일은 이 자동화가 전담.
- **마찰 줄이는 팁**: Cowork가 대시보드를 처음부터 이 배포 폴더(`netlify-deploy/index.html`)에 직접 쓰게 하면 복사 단계가 사라짐.
