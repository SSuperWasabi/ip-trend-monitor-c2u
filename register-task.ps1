<#
  register-task.ps1  —  무인 자동배포용 Windows 작업 스케줄러 등록

  매일 지정 시각에 update.ps1 -Unattended 를 실행합니다.
  update.ps1 은 변경이 없으면 알아서 건너뛰므로, 매일 돌려도 새 대시보드가 있을 때만 배포됩니다.

  사용법(관리자 권한 불필요, 현재 사용자 작업으로 등록):
      powershell -ExecutionPolicy Bypass -File .\register-task.ps1
      powershell -ExecutionPolicy Bypass -File .\register-task.ps1 -At "09:30"
      powershell -ExecutionPolicy Bypass -File .\register-task.ps1 -Remove   # 등록 해제
#>
param(
    [string]$At = "09:30",
    [string]$TaskName = "IP-Trend-Monitor AutoDeploy",
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$deployDir  = $PSScriptRoot
$scriptPath = Join-Path $deployDir 'update.ps1'

if ($Remove) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "[해제] 작업 '$TaskName' 등록을 해제했습니다." -ForegroundColor Yellow
    exit 0
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Unattended"
$trigger = New-ScheduledTaskTrigger -Daily -At $At
# 로그인 상태에서 실행(자격증명/소스 경로 접근), 누락 시 재시도
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "[등록] 작업 '$TaskName' 등록 완료 — 매일 $At 에 자동 감지·배포합니다." -ForegroundColor Green
Write-Host "       대상 스크립트: $scriptPath -Unattended" -ForegroundColor Gray
Write-Host "       지금 즉시 한 번 실행: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host "       등록 해제:          .\register-task.ps1 -Remove" -ForegroundColor Gray

