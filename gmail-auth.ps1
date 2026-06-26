<#
  gmail-auth.ps1  —  Gmail 무인 초안용 1회성 인증

  Google Cloud OAuth(데스크톱) 클라이언트의 ClientId/ClientSecret 으로 동의 후
  refresh_token 을 받아 gmail-config.dat 에 DPAPI 암호화 저장합니다(이 PC/계정 전용).
  이후 update.ps1 이 무인으로 실제 Gmail 저장 초안을 생성합니다.

  사전 준비(브라우저, 1회): GMAIL-SETUP.md 참고 (Gmail API 사용 설정 + OAuth 데스크톱 클라이언트 생성)

  사용법:
      powershell -ExecutionPolicy Bypass -File .\gmail-auth.ps1 -ClientId "xxxx.apps.googleusercontent.com" -ClientSecret "yyyy"
#>
param(
    [Parameter(Mandatory)][string]$ClientId,
    [Parameter(Mandatory)][string]$ClientSecret,
    [int]$Port = 8765
)
$ErrorActionPreference = 'Stop'
$deployDir = $PSScriptRoot
$scope     = 'https://www.googleapis.com/auth/gmail.compose'
$redirect  = "http://localhost:$Port/"
$authUrl   = "https://accounts.google.com/o/oauth2/v2/auth" +
             "?client_id=$([uri]::EscapeDataString($ClientId))" +
             "&redirect_uri=$([uri]::EscapeDataString($redirect))" +
             "&response_type=code" +
             "&scope=$([uri]::EscapeDataString($scope))" +
             "&access_type=offline&prompt=consent"

# 로컬 루프백 리스너(관리자 권한 불필요)
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "브라우저에서 Google 동의 화면을 엽니다... (계정: 본인 com2us 메일)" -ForegroundColor Cyan
Start-Process $authUrl

$client = $listener.AcceptTcpClient()
$stream = $client.GetStream()
$reader = [System.IO.StreamReader]::new($stream)
$requestLine = $reader.ReadLine()
$respHtml = "<html><head><meta charset='utf-8'></head><body style='font-family:sans-serif'>인증이 완료되었습니다. 이 창을 닫고 PowerShell로 돌아가세요.</body></html>"
$resp = "HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nConnection: close`r`nContent-Length: $([Text.Encoding]::UTF8.GetByteCount($respHtml))`r`n`r`n$respHtml"
$wbuf = [Text.Encoding]::UTF8.GetBytes($resp)
$stream.Write($wbuf, 0, $wbuf.Length); $stream.Flush()
$client.Close(); $listener.Stop()

if ($requestLine -match 'error=([^&\s]+)') { throw "OAuth 오류: $([uri]::UnescapeDataString($Matches[1]))" }
if ($requestLine -notmatch 'code=([^&\s]+)') { throw "인가 코드를 받지 못했습니다. 다시 시도하세요." }
$code = [uri]::UnescapeDataString($Matches[1])

$tok = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
    code          = $code
    client_id     = $ClientId
    client_secret = $ClientSecret
    redirect_uri  = $redirect
    grant_type    = 'authorization_code'
}
if (-not $tok.refresh_token) {
    throw "refresh_token 을 받지 못했습니다. https://myaccount.google.com/permissions 에서 이 앱 액세스를 제거한 뒤 다시 실행하세요(prompt=consent 필요)."
}

$cfgJson = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    refresh_token = $tok.refresh_token
} | ConvertTo-Json -Compress

$sec = ConvertTo-SecureString $cfgJson -AsPlainText -Force
$sec | ConvertFrom-SecureString | Set-Content -LiteralPath (Join-Path $deployDir 'gmail-config.dat')

Write-Host "[저장] gmail-config.dat (DPAPI 암호화, 이 PC/계정에서만 복호화 가능)" -ForegroundColor Green
Write-Host "이제 update.ps1 이 무인으로 실제 Gmail 저장 초안을 생성합니다." -ForegroundColor Green

