<#
  register-task.ps1  —  파일 감시 자동배포 상주 등록 (시작프로그램 방식)

  watch.ps1(index.html 변경 감시 → update.ps1 실행)을 다음과 같이 등록/시작합니다.
   - 로그온 시 자동 시작: 사용자 '시작프로그램' 폴더에 숨김 실행 바로가기 생성(권한 불필요)
   - 지금 즉시 시작: 백그라운드로 watch.ps1 실행(중복은 뮤텍스로 방지)
   - 구버전 시간기준 작업("IP-Trend-Monitor AutoDeploy")이 있으면 제거

  배포 트리거는 '시간'이 아니라 '파일 변경'입니다.

  사용법:
      powershell -ExecutionPolicy Bypass -File .\register-task.ps1
      powershell -ExecutionPolicy Bypass -File .\register-task.ps1 -Remove
#>
param([switch]$Remove)
$ErrorActionPreference = 'Stop'
$deployDir = $PSScriptRoot
$watch     = Join-Path $deployDir 'watch.ps1'
$startup   = [Environment]::GetFolderPath('Startup')
$lnk       = Join-Path $startup 'IP-Trend-Monitor-Watch.lnk'
$psExe     = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$psArgs    = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watch`""

# 구버전 시간기준/스케줄러 작업 정리(있으면)
foreach ($t in 'IP-Trend-Monitor AutoDeploy','IP-Trend-Monitor Watch') {
    Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
}

# 실행 여부는 watch.ps1 이 잡는 뮤텍스로 정확히 판정(명령줄 문자열 오탐 방지)
function Test-WatcherRunning {
    try { $m = [System.Threading.Mutex]::OpenExisting('Local\IPTrendMonitorWatcher'); $m.Dispose(); $true }
    catch { $false }
}
function Stop-Watcher {
    $pidFile = Join-Path $deployDir 'watch.pid'
    if (Test-Path -LiteralPath $pidFile) {
        $wpid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
        if ($wpid) { Stop-Process -Id ([int]$wpid) -Force -ErrorAction SilentlyContinue }
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    }
}

if ($Remove) {
    if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force }
    Stop-Watcher
    Write-Host "[해제] 시작프로그램 등록 해제 + 감시 프로세스 종료" -ForegroundColor Yellow
    exit 0
}

# 시작프로그램 바로가기 생성(숨김 실행)
$sh = New-Object -ComObject WScript.Shell
$sc = $sh.CreateShortcut($lnk)
$sc.TargetPath        = $psExe
$sc.Arguments         = $psArgs
$sc.WorkingDirectory  = $deployDir
$sc.WindowStyle       = 7   # 최소화
$sc.Description        = "IP Trend Monitor — index.html 변경 감시 자동배포"
$sc.Save()
Write-Host "[등록] 시작프로그램 바로가기 생성: $lnk" -ForegroundColor Green

# 지금 즉시 시작(이미 실행 중이면 watch.ps1 뮤텍스가 자동 종료)
if (-not (Test-WatcherRunning)) {
    Start-Process -FilePath $psExe -ArgumentList $psArgs -WorkingDirectory $deployDir -WindowStyle Hidden
    Write-Host "[시작] 감시 프로세스 시작됨 (index.html 변경 시 즉시 배포)" -ForegroundColor Green
} else {
    Write-Host "[정보] 감시 프로세스가 이미 실행 중입니다." -ForegroundColor Gray
}
Write-Host "       로그:      $deployDir\watch.log" -ForegroundColor Gray
Write-Host "       등록 해제: .\register-task.ps1 -Remove" -ForegroundColor Gray

