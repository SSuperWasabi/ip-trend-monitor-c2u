<#
  update.ps1  —  IP Trend Monitor 주간 갱신 자동화 (감지 → 배포 → 메일 초안)

  하는 일:
    1) 새로 생성된 대시보드(index.html)를 이 배포 폴더로 복사
    2) 변경이 있으면 git commit + push  ->  GitHub Actions가 라이브에 자동 배포
    3) 라이브 링크가 채워진 Gmail 작성용 .url 바로가기 + email-draft.txt 생성
       (대화형 실행 시에는 Gmail 작성창을 바로 띄움)

  사용법 (이 폴더에서):
      powershell -ExecutionPolicy Bypass -File .\update.ps1
      powershell -ExecutionPolicy Bypass -File .\update.ps1 -Source "C:\다른\경로\index.html"
      powershell -ExecutionPolicy Bypass -File .\update.ps1 -Unattended   # 작업 스케줄러용(브라우저 안 띄움)
#>
param(
    [string]$Source = "C:\Users\jasonbae\Downloads\NAVER WORKS\ip-trend-monitor\index.html",
    [switch]$Unattended
)

$ErrorActionPreference = 'Stop'
$deployDir = $PSScriptRoot
$dest      = Join-Path $deployDir 'index.html'
$liveUrl   = 'https://ip-trend-monitor-c2u.netlify.app'

if (-not (Test-Path -LiteralPath $Source)) {
    Write-Host "[오류] 소스 대시보드를 찾을 수 없습니다:" -ForegroundColor Red
    Write-Host "       $Source" -ForegroundColor Red
    Write-Host "       -Source 옵션으로 올바른 index.html 경로를 지정하세요." -ForegroundColor Yellow
    exit 1
}

Copy-Item -LiteralPath $Source -Destination $dest -Force
Write-Host "[복사] $Source" -ForegroundColor Gray
Write-Host "    -> $dest" -ForegroundColor Green

# 대시보드 기준일을 <title> 등에서 추출
$content = Get-Content -LiteralPath $dest -Raw
$dateTag = (Get-Date -Format 'yyyy-MM-dd')
if ($content -match '(\d{4}-\d{2}-\d{2})') { $dateTag = $Matches[1] }

Push-Location $deployDir
try {
    git add index.html | Out-Null
    if (-not (git status --porcelain index.html)) {
        Write-Host "[건너뜀] index.html 변경 사항이 없습니다. 이미 최신입니다." -ForegroundColor Yellow
        exit 0
    }

    git -c commit.gpgsign=false commit -m "content: update dashboard to $dateTag"
    git push origin main

    Write-Host ""
    Write-Host "[완료] push 완료 — GitHub Actions가 자동 배포합니다 (약 1분)." -ForegroundColor Green
    Write-Host "   라이브   : $liveUrl" -ForegroundColor Cyan
    Write-Host "   Actions  : https://github.com/SSuperWasabi/ip-trend-monitor-c2u/actions" -ForegroundColor Cyan

    # ---- 메일 초안 준비 (B) ----
    $subject = "[IP 트렌드] 뉴스 모니터 대시보드 — $dateTag"
    $body = @"
안녕하세요,

이번 주 IP 트렌드 뉴스 모니터 대시보드가 업데이트되었습니다 (기준일: $dateTag).

▶ 라이브 대시보드: $liveUrl

필터·정렬이 가능한 인터랙티브 대시보드입니다. 주요 트렌드와 뉴스는 위 링크에서 바로 확인하실 수 있습니다.

감사합니다.
"@

    # email-draft.txt: 복사해서 쓸 수 있는 제목+본문
    $draftText = "제목: $subject`r`n`r`n$body"
    Set-Content -LiteralPath (Join-Path $deployDir 'email-draft.txt') -Value $draftText -Encoding UTF8

    # Gmail 작성창 딥링크(제목·본문·라이브링크 미리 채움)
    $su   = [uri]::EscapeDataString($subject)
    $bd   = [uri]::EscapeDataString($body)
    $composeUrl = "https://mail.google.com/mail/?view=cm&fs=1&tf=1&su=$su&body=$bd"

    # 더블클릭하면 작성창이 열리는 .url 바로가기 생성
    $urlFile = Join-Path $deployDir '메일-초안-열기.url'
    Set-Content -LiteralPath $urlFile -Value "[InternetShortcut]`r`nURL=$composeUrl" -Encoding ASCII

    if ($Unattended) {
        Write-Host "[메일] 초안 준비됨 -> email-draft.txt / 메일-초안-열기.url (더블클릭 시 작성창)" -ForegroundColor Green
    } else {
        Write-Host "[메일] Gmail 작성창을 엽니다 (Ctrl+S로 초안 저장 또는 발송)..." -ForegroundColor Green
        Start-Process $composeUrl
    }
}
finally {
    Pop-Location
}

