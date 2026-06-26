<#
  update.ps1  —  IP Trend Monitor 주간 갱신 자동화 (감지 → 배포 → 메일 초안)

  동작:
    1) 콘텐츠 확보 (둘 다 자동 처리)
       - Cowork가 이 폴더의 index.html에 직접 쓴 경우 → 그대로 사용(복사 생략)
       - 아니면 -Source(기본: NAVER WORKS 경로)에서 복사
    2) 변경이 있으면 git commit + push  ->  GitHub Actions가 라이브에 자동 배포
    3) 메일 초안 준비
       - gmail-config.dat 가 있으면(=gmail-auth.ps1 완료) Gmail API로 *실제 저장 초안*을 무인 생성
       - 없으면 email-draft.txt + 메일-초안-열기.url 생성(대화형 실행 시 작성창도 띄움)

  사용법(이 폴더에서):
      powershell -ExecutionPolicy Bypass -File .\update.ps1
      powershell -ExecutionPolicy Bypass -File .\update.ps1 -Source "C:\다른\경로\index.html"
      powershell -ExecutionPolicy Bypass -File .\update.ps1 -Unattended        # 스케줄러용(브라우저 안 띄움)
      powershell -ExecutionPolicy Bypass -File .\update.ps1 -To "team@com2us.com","me@com2us.com"
#>
param(
    [string]$Source = "C:\Users\jasonbae\Downloads\NAVER WORKS\ip-trend-monitor\index.html",
    [string[]]$To,
    [switch]$Unattended
)

$ErrorActionPreference = 'Stop'
$deployDir = $PSScriptRoot
$dest      = Join-Path $deployDir 'index.html'
$liveUrl   = 'https://ip-trend-monitor-c2u.netlify.app'

Push-Location $deployDir
try {
    # ---- 1) 콘텐츠 확보 (Cowork 직접쓰기 자동 감지) ----
    git add index.html 2>$null | Out-Null
    $alreadyChanged = [bool](git status --porcelain -- index.html)

    if ($alreadyChanged) {
        Write-Host "[감지] index.html 이 이미 변경됨(Cowork 직접 쓰기로 판단) → 복사 생략" -ForegroundColor Cyan
    }
    elseif (Test-Path -LiteralPath $Source) {
        Copy-Item -LiteralPath $Source -Destination $dest -Force
        Write-Host "[복사] $Source" -ForegroundColor Gray
        Write-Host "    -> $dest" -ForegroundColor Green
        git add index.html 2>$null | Out-Null
    }
    else {
        Write-Host "[건너뜀] 배포 폴더 index.html 변경 없음, 소스도 없음:" -ForegroundColor Yellow
        Write-Host "         $Source" -ForegroundColor Yellow
        exit 0
    }

    if (-not (git status --porcelain -- index.html)) {
        Write-Host "[건너뜀] index.html 변경 사항이 없습니다. 이미 최신입니다." -ForegroundColor Yellow
        exit 0
    }

    # 대시보드 기준일 추출
    $content = Get-Content -LiteralPath $dest -Raw
    $dateTag = (Get-Date -Format 'yyyy-MM-dd')
    if ($content -match '(\d{4}-\d{2}-\d{2})') { $dateTag = $Matches[1] }

    # ---- 2) 커밋 & 푸시 ----
    git -c commit.gpgsign=false commit -m "content: update dashboard to $dateTag"
    git push origin main

    Write-Host ""
    Write-Host "[완료] push 완료 — GitHub Actions가 자동 배포합니다 (약 1분)." -ForegroundColor Green
    Write-Host "   라이브   : $liveUrl" -ForegroundColor Cyan
    Write-Host "   Actions  : https://github.com/SSuperWasabi/ip-trend-monitor-c2u/actions" -ForegroundColor Cyan

    # ---- 3) 메일 초안 ----
    # 수신자: -To > mail-to.txt(줄/쉼표 구분) > 기본 본인
    if (-not $To -or $To.Count -eq 0) {
        $mailToFile = Join-Path $deployDir 'mail-to.txt'
        if (Test-Path -LiteralPath $mailToFile) {
            $To = (Get-Content -LiteralPath $mailToFile -Raw) -split '[\r\n,;]+' | Where-Object { $_ -match '@' }
        }
    }
    if (-not $To -or $To.Count -eq 0) { $To = @('jasonbae@com2us.com') }

    $subject = "[IP 트렌드] 뉴스 모니터 대시보드 — $dateTag"
    $body = @"
안녕하세요,

이번 주 IP 트렌드 뉴스 모니터 대시보드가 업데이트되었습니다 (기준일: $dateTag).

▶ 라이브 대시보드: $liveUrl

필터·정렬이 가능한 인터랙티브 대시보드입니다. 주요 트렌드와 뉴스는 위 링크에서 바로 확인하실 수 있습니다.

감사합니다.
"@

    # 항상 텍스트 산출물 남김(백업)
    Set-Content -LiteralPath (Join-Path $deployDir 'email-draft.txt') -Value "받는사람: $($To -join ', ')`r`n제목: $subject`r`n`r`n$body" -Encoding UTF8

    $gmailCfg    = Join-Path $deployDir 'gmail-config.dat'
    $gmailScript = Join-Path $deployDir 'gmail-draft.ps1'

    if ((Test-Path -LiteralPath $gmailCfg) -and (Test-Path -LiteralPath $gmailScript)) {
        # 완전 무인: Gmail API로 실제 저장 초안 생성
        try {
            & $gmailScript -To $To -Subject $subject -Body $body
            Write-Host "[메일] Gmail 저장 초안을 생성했습니다(임시보관함 확인)." -ForegroundColor Green
        } catch {
            Write-Host "[메일][경고] Gmail 초안 생성 실패: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "         email-draft.txt 로 대체 보관했습니다." -ForegroundColor Yellow
        }
    }
    else {
        # 대체: 작성창 딥링크 .url + (대화형) 작성창 열기
        $su = [uri]::EscapeDataString($subject)
        $bd = [uri]::EscapeDataString($body)
        $toq = [uri]::EscapeDataString(($To -join ','))
        $composeUrl = "https://mail.google.com/mail/?view=cm&fs=1&tf=1&to=$toq&su=$su&body=$bd"
        Set-Content -LiteralPath (Join-Path $deployDir '메일-초안-열기.url') -Value "[InternetShortcut]`r`nURL=$composeUrl" -Encoding ASCII

        if ($Unattended) {
            Write-Host "[메일] 초안 준비됨 -> email-draft.txt / 메일-초안-열기.url (더블클릭 시 작성창)" -ForegroundColor Green
            Write-Host "       완전 무인 저장-초안을 원하면 gmail-auth.ps1 을 1회 실행하세요." -ForegroundColor Gray
        } else {
            Write-Host "[메일] Gmail 작성창을 엽니다 (Ctrl+S로 초안 저장 또는 발송)..." -ForegroundColor Green
            Start-Process $composeUrl
        }
    }
}
finally {
    Pop-Location
}

