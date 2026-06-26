<#
  gmail-draft.ps1  —  Gmail API로 *실제 저장 초안* 생성 (무인)

  gmail-config.dat(=gmail-auth.ps1 결과)의 refresh_token 으로 액세스 토큰을 발급해
  Gmail API users.drafts.create 를 호출합니다. 스코프: gmail.compose(초안 생성 전용).
  보통 update.ps1 이 자동 호출하며, 단독 실행도 가능합니다.

  사용법:
      powershell -ExecutionPolicy Bypass -File .\gmail-draft.ps1 -To "team@com2us.com" -Subject "제목" -Body "본문"
#>
param(
    [Parameter(Mandatory)][string[]]$To,
    [string]$Subject = '',
    [string]$Body    = ''
)
$ErrorActionPreference = 'Stop'
$deployDir = $PSScriptRoot
$cfgFile   = Join-Path $deployDir 'gmail-config.dat'
if (-not (Test-Path -LiteralPath $cfgFile)) {
    throw "gmail-config.dat 가 없습니다. 먼저 gmail-auth.ps1 을 1회 실행하세요."
}

# 설정 복호화(DPAPI)
$enc  = Get-Content -LiteralPath $cfgFile -Raw
$sec  = $enc | ConvertTo-SecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
try   { $cfg = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) | ConvertFrom-Json }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

# 액세스 토큰 발급
$tok = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
    client_id     = $cfg.client_id
    client_secret = $cfg.client_secret
    refresh_token = $cfg.refresh_token
    grant_type    = 'refresh_token'
}

# RFC822 메시지 구성 (제목 UTF-8 encoded-word, 본문 base64). From 은 생략 → Gmail이 계정으로 채움.
$encSubject = "=?UTF-8?B?" + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Subject)) + "?="
$bodyB64    = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Body))
$nl  = "`r`n"
$mime = "To: $($To -join ', ')$nl" +
        "Subject: $encSubject$nl" +
        "MIME-Version: 1.0$nl" +
        "Content-Type: text/plain; charset=UTF-8$nl" +
        "Content-Transfer-Encoding: base64$nl$nl" +
        $bodyB64

# base64url 인코딩
$raw = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($mime)).Replace('+','-').Replace('/','_').TrimEnd('=')

$payload = @{ message = @{ raw = $raw } } | ConvertTo-Json
$draft = Invoke-RestMethod -Method Post `
    -Uri 'https://gmail.googleapis.com/gmail/v1/users/me/drafts' `
    -Headers @{ Authorization = "Bearer $($tok.access_token)" } `
    -ContentType 'application/json; charset=utf-8' `
    -Body $payload

Write-Host "[Gmail] 저장 초안 생성 완료 (draftId: $($draft.id))" -ForegroundColor Green

