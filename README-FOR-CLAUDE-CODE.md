# IP Trend Monitor — Claude Code 핸드오프

이 폴더를 Claude Code로 열면, 라이브 대시보드 배포와 자동배포(Git) 설정을 Claude Code가 처리합니다.
(데이터 수집/대시보드 생성은 Cowork에서, 배포/호스팅은 Claude Code에서 — 역할 분담)

## 이 폴더 구성
- `index.html`   : 현재 IP Trend News Monitor 대시보드 (동적, 필터 포함)
- `netlify.toml` : 정적 배포 설정
- `DEPLOY.md`    : 수동 배포 명령 참고

## 기존 Netlify 사이트 (새로 만들지 말 것)
- 이름:  ip-trend-monitor-c2u
- siteId: fb3ef42a-f048-4d0b-a665-fda0a18bb7ec
- URL:   https://ip-trend-monitor-c2u.netlify.app

---

## Claude Code에 이렇게 시키세요 (그대로 복사해 붙여넣기)

> 이 폴더를 기존 Netlify 사이트(이름 `ip-trend-monitor-c2u`, siteId `fb3ef42a-f048-4d0b-a665-fda0a18bb7ec`)에
> 배포해줘. 그다음 이 폴더를 git 저장소로 만들고 내 GitHub에 새 비공개 저장소로 push한 뒤,
> Netlify 사이트를 그 GitHub 저장소에 연결해서 **push할 때마다 자동 배포**되게 설정해줘.
> 끝나면 라이브 URL과 저장소 주소를 알려줘.

Claude Code는 터미널 + Netlify CLI + git + GitHub 연동이 되므로 위 작업을 끝까지 수행할 수 있습니다.
(최초 1회 `netlify login`, GitHub 인증이 필요할 수 있습니다.)

## 매주 갱신 흐름 (역할 분담)
1. **Cowork**: `ip-dashboard-update` 스킬로 트렌드 모니터를 최신화 → 생성된 HTML을 이 폴더의 `index.html`로 교체
   (Cowork가 이 폴더에 직접 쓰게 하려면 폴더 접근 권한을 한 번 부여)
2. **Git push**: 이 폴더에서 commit + push (Claude Code에 "변경분 커밋하고 푸시해줘")
3. Netlify가 **자동 배포** → 같은 URL에 새 내용 반영
4. 그 URL을 팀 메일에 링크 (메일 초안은 Cowork에서 자동 생성)

## 참고
- 매주 데이터 수집(hiyeon 클리핑·web_search)은 **Cowork의 커넥터**가 필요합니다.
  Claude Code에서 똑같이 하려면 Gmail MCP 등을 Claude Code에도 설정해야 합니다.
  가장 간단한 분담: 생성=Cowork, 배포=Claude Code(+Git 자동배포).
