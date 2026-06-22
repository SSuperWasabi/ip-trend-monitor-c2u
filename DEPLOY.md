# IP Trend Monitor — Netlify 배포 가이드 (Option A: Claude Code)

이 폴더를 그대로 Netlify에 올리면 인터랙티브 대시보드가 라이브 URL로 공개됩니다.
이미 생성된 사이트에 배포합니다 (새로 만들지 마세요).

- 사이트 이름: `ip-trend-monitor-c2u`
- 사이트 ID:   `fb3ef42a-f048-4d0b-a665-fda0a18bb7ec`
- 라이브 URL:  https://ip-trend-monitor-c2u.netlify.app

---

## 1. 최초 1회 세팅 (Claude Code 터미널)
```bash
npm i -g netlify-cli        # 이미 있으면 생략
netlify login               # 브라우저로 Netlify 로그인 (jasonbae@com2us.com)
```
(또는 토큰 사용: Netlify > User settings > Applications > Personal access token 발급 후
 `export NETLIFY_AUTH_TOKEN=xxxxx`)

## 2. 배포 (이 폴더에서 실행)
```bash
cd netlify-deploy
netlify deploy --prod --dir . --site fb3ef42a-f048-4d0b-a665-fda0a18bb7ec
```
완료되면 https://ip-trend-monitor-c2u.netlify.app 에 반영됩니다.

> Claude Code에서는 "이 폴더를 위 site로 netlify 배포해줘" 라고 해도 됩니다.
> (Claude Code의 Netlify MCP가 배포까지 자동 처리)

## 3. 보안(공개 범위) — 택1
- 비밀번호 보호: Netlify > Site > Site configuration > Access control > Password protection
- 또는 Team(SSO) 로그인 제한.
IP 동향이라 외부 공개가 부담되면 비밀번호 보호 권장.

## 4. 매주 갱신 흐름
1. Cowork(또는 Claude Code)에서 `ip-dashboard-update` 스킬로 트렌드 모니터 최신화
2. 생성된 HTML을 이 폴더의 index.html로 교체
3. 위 2번 배포 명령 재실행 → 같은 URL에 새 내용 반영
4. 그 URL을 팀 메일에 링크

## (선택) 완전 자동화: Git push-to-deploy
- 이 폴더를 GitHub 저장소로 만들고 Netlify 사이트에 연결하면,
  push할 때마다 자동 배포됩니다. 이후 주간 작업이 commit+push만 하면 끝.
- 설정을 원하면 Claude에게 "Git 자동배포로 세팅해줘" 라고 요청하세요.
