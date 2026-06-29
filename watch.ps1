<#
  watch.ps1  —  index.html 파일 변경 감시 → 즉시 자동 배포 (시간 기준 아님)

  배포 폴더의 index.html 이 바뀌면(=Cowork가 새 대시보드 저장) update.ps1 -Unattended 를 실행합니다.
  보통 '시작프로그램(Startup)' 등록으로 로그온 시 자동 시작합니다(register-task.ps1). 로그아웃 동안의
  변경은 다음 시작 시 catch-up 으로 한 번 반영합니다.

  수동 실행(테스트): powershell -ExecutionPolicy Bypass -File .\watch.ps1
#>
$ErrorActionPreference = 'Stop'
$deployDir = $PSScriptRoot
$target    = 'index.html'
$logFile   = Join-Path $deployDir 'watch.log'

function Write-Log($msg) {
    Add-Content -LiteralPath $logFile -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding UTF8
}

# 단일 인스턴스 보장(시작프로그램 + 수동 시작 중복 방지)
$mutex = New-Object System.Threading.Mutex($false, 'Local\IPTrendMonitorWatcher')
if (-not $mutex.WaitOne(0)) {
    Add-Content -LiteralPath $logFile -Value ("{0}  이미 실행 중 - 새 인스턴스 종료" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
    return
}
$pidFile = Join-Path $deployDir 'watch.pid'
Set-Content -LiteralPath $pidFile -Value $PID -Encoding ASCII

function Invoke-Update($reason) {
    Write-Log "trigger: $reason -> update.ps1 실행"
    # 별도 프로세스로 실행(update.ps1 내부의 exit 가 감시 루프를 끝내지 않도록 격리)
    # git 등 네이티브 도구가 stderr에 정상 진행메시지를 쓰므로, 캡처 중엔 Stop 비활성화
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $deployDir 'update.ps1') -Unattended 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $eap
    }
    Add-Content -LiteralPath $logFile -Value $out.TrimEnd() -Encoding UTF8
    Write-Log "update.ps1 종료 (exit=$code)"
}

Write-Log "watcher 시작 (감시: $deployDir\$target)"
# 시작 시 1회 catch-up (감시가 꺼져 있던 동안의 변경 반영; 변경 없으면 update.ps1이 알아서 건너뜀)
try { Invoke-Update "startup catch-up" } catch { Write-Log "catch-up 오류: $($_.Exception.Message)" }

$fsw = New-Object System.IO.FileSystemWatcher $deployDir, $target
$fsw.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::Size -bor [System.IO.NotifyFilters]::FileName
$fsw.EnableRaisingEvents = $true
Register-ObjectEvent $fsw Changed -SourceIdentifier IdxChg | Out-Null
Register-ObjectEvent $fsw Created -SourceIdentifier IdxNew | Out-Null
Register-ObjectEvent $fsw Renamed -SourceIdentifier IdxRen | Out-Null

try {
    while ($true) {
        $ev = Wait-Event -Timeout 3600           # 이벤트 대기(1시간마다 하트비트)
        if ($null -ne $ev) {
            Start-Sleep -Seconds 3               # 디바운스: 파일 쓰기 완료 대기
            Get-Event | Remove-Event             # 누적 이벤트 비우기(중복 배포 방지)
            try { Invoke-Update "file change" } catch { Write-Log "update 오류: $($_.Exception.Message)" }
        }
    }
}
finally {
    Get-EventSubscriber | Unregister-Event -ErrorAction SilentlyContinue
    $fsw.Dispose()
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    Write-Log "watcher 종료"
}




