<#
  deploy-verify.ps1  —  push 후 라이브 반영 감시 → 지연 시 Windows 토스트 알림

  update.ps1 이 push 직후 별도 백그라운드 프로세스로 실행합니다.
  라이브 URL을 PollSec 간격으로 조회해 '업데이트: <DateTag>' 가 보이면 정상 종료하고,
  TimeoutMin 안에 반영되지 않으면 Windows 알림(토스트)을 띄웁니다.
  push 실패·Actions 실패·GitHub 장애 등 원인과 무관하게 "라이브 최종 반영"만 기준으로 판정합니다.

  수동 테스트:
      powershell -ExecutionPolicy Bypass -File .\deploy-verify.ps1 -DateTag 2099-01-01 -TimeoutMin 0    # 알림 강제 표시
      powershell -ExecutionPolicy Bypass -File .\deploy-verify.ps1 -DateTag 2026-07-20 -TimeoutMin 1 -PollSec 5   # 성공 경로
#>
param(
    [Parameter(Mandatory)][string]$DateTag,
    [string]$LiveUrl = 'https://ssuperwasabi.github.io/ip-trend-monitor-c2u/',
    [int]$TimeoutMin = 30,
    [int]$PollSec    = 600
)
$ErrorActionPreference = 'Continue'
$deployDir  = $PSScriptRoot
$logFile    = Join-Path $deployDir 'watch.log'
$actionsUrl = 'https://github.com/SSuperWasabi/ip-trend-monitor-c2u/actions'

function Write-Log($msg) {
    Add-Content -LiteralPath $logFile -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding UTF8
}

function Show-Toast([string]$title, [string]$body) {
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType=WindowsRuntime] | Out-Null
        $xml = @"
<toast activationType="protocol" launch="$LiveUrl" scenario="reminder">
  <visual><binding template="ToastGeneric">
    <text>$title</text>
    <text>$body</text>
  </binding></visual>
  <actions>
    <action content="라이브 확인" activationType="protocol" arguments="$LiveUrl"/>
    <action content="Actions 상태" activationType="protocol" arguments="$actionsUrl"/>
  </actions>
</toast>
"@
        $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $doc.LoadXml($xml)
        # Windows PowerShell 의 시작메뉴 AUMID — 별도 앱 등록 없이 토스트 표시 가능
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($doc)
        return $true
    } catch {
        Write-Log "deploy-verify: 토스트 실패($($_.Exception.Message)) → 팝업으로 대체"
        return $false
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$deadline = (Get-Date).AddMinutes($TimeoutMin)
Write-Log "deploy-verify: 감시 시작 — 기대 날짜 $DateTag, 제한 $TimeoutMin 분"

while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri ($LiveUrl + '?v=' + (Get-Date -Format 'yyyyMMddHHmmss')) -UseBasicParsing -TimeoutSec 30
        if ($r.Content -match ('업데이트:\s*' + [regex]::Escape($DateTag))) {
            Write-Log "deploy-verify: 라이브 반영 확인($DateTag) — 정상"
            exit 0
        }
    } catch {
        Write-Log "deploy-verify: 조회 실패(계속 재시도): $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $PollSec
}

Write-Log "deploy-verify: [경고] $TimeoutMin 분 내 라이브 미반영 → Windows 알림 표시"
$title = "IP Trend 대시보드 배포 지연"
$body  = "푸시 후 $TimeoutMin 분이 지나도 라이브에 $DateTag 업데이트가 반영되지 않았습니다. GitHub Actions 상태를 확인하세요."
if (-not (Show-Toast $title $body)) {
    (New-Object -ComObject WScript.Shell).Popup("$title`n`n$body`n`n$actionsUrl", 0, $title, 48) | Out-Null
}
exit 1
