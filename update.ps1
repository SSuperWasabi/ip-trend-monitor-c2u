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
      powershell -ExecutionPolicy Bypass -File .\update.ps1 -To "team@example.com","me@example.com"
#>
param(
    [string]$Source = "C:\Users\jasonbae\Downloads\NAVER WORKS\ip-trend-monitor\index.html",
    [string[]]$To,
    [switch]$Unattended
)

# git이 stderr로 내는 정상 경고(LF→CRLF 등)를 치명적 오류로 처리하지 않도록 Continue 사용.
# (분기/배포 판단은 git status·exit code로 명시 확인하므로 Stop 없이도 안전)
$ErrorActionPreference = 'Continue'
$deployDir = $PSScriptRoot
$dest      = Join-Path $deployDir 'index.html'
$liveUrl   = 'https://ssuperwasabi.github.io/ip-trend-monitor-c2u/'

# 이 저장소에서 CRLF 자동변환/경고 비활성화(파일은 있는 그대로 다룸)
git -C $deployDir config core.autocrlf false 2>$null | Out-Null

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
    if (-not $To -or $To.Count -eq 0) { $To = @() }  # 개인 이메일은 gitignore된 mail-to.txt 에서만 지정(공개 저장소에 미포함)

    # build-email.ps1 로 대시보드를 파싱해 HTML+텍스트 본문 생성(템플릿)
    $mail = & (Join-Path $deployDir 'build-email.ps1') -DashboardPath $dest -LiveUrl $liveUrl -DateTag $dateTag
    $subject = $mail.Subject

    # 항상 산출물 남김(백업/미리보기)
    Set-Content -LiteralPath (Join-Path $deployDir 'email-draft.txt')  -Value $mail.Text -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $deployDir 'email-draft.html') -Value $mail.Html -Encoding UTF8

    $gmailCfg    = Join-Path $deployDir 'gmail-config.dat'
    $gmailScript = Join-Path $deployDir 'gmail-draft.ps1'

    if ((Test-Path -LiteralPath $gmailCfg) -and (Test-Path -LiteralPath $gmailScript)) {
        # 완전 무인: Gmail API로 실제 저장 초안(HTML) 생성
        try {
            & $gmailScript -To $To -Subject $subject -Body $mail.Text -HtmlBody $mail.Html
            Write-Host "[메일] Gmail HTML 저장 초안을 생성했습니다(임시보관함 확인)." -ForegroundColor Green
        } catch {
            Write-Host "[메일][경고] Gmail 초안 생성 실패: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "         email-draft.html / .txt 로 대체 보관했습니다." -ForegroundColor Yellow
        }
    }
    else {
        # 대체: HTML 미리보기 파일 + 작성창 딥링크(.url, 텍스트 본문)
        $su  = [uri]::EscapeDataString($subject)
        $bd  = [uri]::EscapeDataString($mail.Text)
        $toq = [uri]::EscapeDataString(($To -join ','))
        $composeUrl = "https://mail.google.com/mail/?view=cm&fs=1&tf=1&to=$toq&su=$su&body=$bd"
        Set-Content -LiteralPath (Join-Path $deployDir '메일-초안-열기.url') -Value "[InternetShortcut]`r`nURL=$composeUrl" -Encoding ASCII

        if ($Unattended) {
            Write-Host "[메일] 초안 준비됨 -> email-draft.html(디자인 미리보기) / 메일-초안-열기.url(작성창)" -ForegroundColor Green
            Write-Host "       완전 무인 HTML 저장-초안을 원하면 gmail-auth.ps1 을 1회 실행하세요(GMAIL-SETUP.md)." -ForegroundColor Gray
        } else {
            Write-Host "[메일] HTML 미리보기(email-draft.html)를 열고, Gmail 작성창도 띄웁니다..." -ForegroundColor Green
            Start-Process (Join-Path $deployDir 'email-draft.html')
            Start-Process $composeUrl
        }
    }
}
finally {
    Pop-Location
}





