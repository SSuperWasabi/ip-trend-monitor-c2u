<#
  update.ps1  —  IP Trend Monitor 주간 갱신 자동화

  하는 일: 새로 생성된 대시보드(index.html)를 이 배포 폴더로 복사한 뒤
           git commit + push 까지 한 번에 처리합니다.
           push되면 GitHub Actions가 https://ip-trend-monitor-c2u.netlify.app 에 자동 배포합니다.

  사용법 (이 폴더에서):
      powershell -ExecutionPolicy Bypass -File .\update.ps1
      powershell -ExecutionPolicy Bypass -File .\update.ps1 -Source "C:\다른\경로\index.html"

  -Source 를 생략하면 아래 기본 경로(Cowork가 생성하는 위치)에서 가져옵니다.
#>
param(
    [string]$Source = "C:\Users\jasonbae\Downloads\NAVER WORKS\ip-trend-monitor\index.html"
)

$ErrorActionPreference = 'Stop'
$deployDir = $PSScriptRoot
$dest      = Join-Path $deployDir 'index.html'

if (-not (Test-Path -LiteralPath $Source)) {
    Write-Host "[오류] 소스 대시보드를 찾을 수 없습니다:" -ForegroundColor Red
    Write-Host "       $Source" -ForegroundColor Red
    Write-Host "       -Source 옵션으로 올바른 index.html 경로를 지정하세요." -ForegroundColor Yellow
    exit 1
}

Copy-Item -LiteralPath $Source -Destination $dest -Force
Write-Host "[복사] $Source" -ForegroundColor Gray
Write-Host "    -> $dest" -ForegroundColor Green

# 대시보드 날짜를 <title> 에서 추출해 커밋 메시지에 사용
$content = Get-Content -LiteralPath $dest -Raw
$dateTag = 'update'
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
    Write-Host "   라이브   : https://ip-trend-monitor-c2u.netlify.app" -ForegroundColor Cyan
    Write-Host "   Actions  : https://github.com/SSuperWasabi/ip-trend-monitor-c2u/actions" -ForegroundColor Cyan
}
finally {
    Pop-Location
}

