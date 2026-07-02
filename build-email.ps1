<#
  build-email.ps1  —  대시보드(index.html)를 파싱해 메일 본문(HTML+텍스트) 생성

  반환: @{ Subject=...; Html=...; Text=... }  (객체 1개만 출력)
  보통 update.ps1 이 호출하며, 단독 실행도 가능(파일로 미리보기 저장).

  단독 실행 예:
      $m = & .\build-email.ps1; $m.Html | Set-Content email-draft.html -Encoding UTF8; start email-draft.html
#>
param(
    [string]$DashboardPath = (Join-Path $PSScriptRoot 'index.html'),
    [string]$LiveUrl       = 'https://ssuperwasabi.github.io/ip-trend-monitor-c2u/',
    [string]$DateTag       = ''
)
$ErrorActionPreference = 'Stop'
$html = Get-Content -LiteralPath $DashboardPath -Raw -Encoding UTF8

if (-not $DateTag) {
    $DateTag = (Get-Date -Format 'yyyy-MM-dd')
    if ($html -match '(\d{4}-\d{2}-\d{2})') { $DateTag = $Matches[1] }
}

# --- 메타(날짜·출처) ---
$metaLine = ''
if ($html -match "IP Trend News Monitor</h1>\s*<div[^>]*>(.*?)</div>") {
    $metaLine = $Matches[1].Trim() -replace '「','' -replace '」',''
}
$total = ''
if ($html -match '전체\((\d+)\)') { $total = $Matches[1] }
$metaFull = $metaLine
if ($total) { $metaFull = "$metaLine · 총 ${total}건" }

# --- 이번 주 핵심 (AI Trend Brief) ---
$highlights = @()
foreach ($m in [regex]::Matches($html, '<div style="font-size:12px;line-height:1\.5;">(.*?)</div>')) {
    $highlights += $m.Groups[1].Value.Trim()
}

# --- 기사 (카테고리/제목/URL/출처) ---
$catColors = @{
    '컴투스'='#991b1b'; '커머스·굿즈'='#92400e'; '팝업·오프라인'='#166534'
    '트랜스미디어'='#3730a3'; '경쟁사'='#5b21b6'; '산업·정책'='#1e40af'
}
$catMap = @{ c2u='컴투스'; commerce='커머스·굿즈'; popup='팝업·오프라인'; transmedia='트랜스미디어'; competitor='경쟁사'; industry='산업·정책' }
$catOrder = @()
$byCat = @{}
# 항목별로 분할 후 각 블록에서 명시적 정규식으로 추출
$opt = [System.Text.RegularExpressions.RegexOptions]::Singleline
$blocks = $html -split 'class="news-item"'
for ($i = 1; $i -lt $blocks.Count; $i++) {
    $b = $blocks[$i]
    $mt = [regex]::Match($b, '<a href="(https?://[^"]+)"[^>]*>(.*?)</a>', $opt)
    if (-not $mt.Success) { continue }
    $url   = $mt.Groups[1].Value.Trim()
    $title = ($mt.Groups[2].Value -replace '<[^>]+>','').Trim()

    $catCode = ''
    $mc = [regex]::Match($b, 'data-cat="([^"]+)"')
    if ($mc.Success) { $catCode = $mc.Groups[1].Value }
    $cat = $catMap[$catCode]; if (-not $cat) { $cat = $catCode }

    $src = ''
    $ms = [regex]::Match($b, '<div class="src-line"><span>(.*?)</span>', $opt)
    if ($ms.Success) {
        $src = $ms.Groups[1].Value
        $src = ($src -replace '\s*\d{4}-\d{2}.*$','')   # 날짜 이후 제거
        $src = ($src -replace '[··•‧・･].*$','')         # 가운뎃점 이후 제거
        $src = $src.Trim()
    }

    if (-not $byCat.ContainsKey($cat)) { $byCat[$cat] = @(); $catOrder += $cat }
    $byCat[$cat] += [pscustomobject]@{ Title=$title; Url=$url; Src=$src }
}

# ================= HTML 본문 =================
$sb = [System.Text.StringBuilder]::new()
$null = $sb.Append(@"
<div style="margin:0;padding:0;background:#f1f5f9;font-family:'Apple SD Gothic Neo','Malgun Gothic',Arial,sans-serif;color:#0f172a;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#f1f5f9"><tr><td align="center" style="padding:20px;">
<table role="presentation" width="640" cellspacing="0" cellpadding="0" border="0" style="width:640px;max-width:100%;">
  <tr><td style="background:#ffffff;border:2px solid #e60012;border-radius:16px;padding:26px 20px;text-align:center;">
    <div style="font-size:13px;font-weight:800;color:#e60012;letter-spacing:1px;margin-bottom:18px;">📊 IP TREND NEWS MONITOR — LIVE DASHBOARD</div>
    <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin:0 auto;"><tr>
      <td bgcolor="#e60012" style="border-radius:12px;">
        <a href="$LiveUrl" target="_blank" style="display:inline-block;padding:16px 40px;font-size:18px;font-weight:800;color:#ffffff;text-decoration:none;border-radius:12px;">IP Trend News Monitor&nbsp;&nbsp;&rarr;</a>
      </td>
    </tr></table>
    <div style="font-size:14px;font-weight:700;color:#e60012;margin-top:18px;">👉 Click to check out ↗</div>
    <div style="font-size:12px;color:#64748b;margin-top:8px;">카테고리 필터·전체 기사 보기 · 매주 자동 갱신되는 라이브 대시보드</div>
  </td></tr>
  <tr><td style="padding:22px 4px 0;">
    <div style="font-size:11px;color:#94a3b8;letter-spacing:1.5px;font-weight:700;text-transform:uppercase;">COM2US · IP BUSINESS TEAM</div>
    <div style="font-size:12px;color:#94a3b8;margin-top:6px;">$metaFull</div>
  </td></tr>
"@)

# 이번 주 핵심
if ($highlights.Count) {
    $null = $sb.Append(@"
  <tr><td style="padding-top:18px;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#0f172a" style="border-radius:14px;"><tr>
      <td bgcolor="#0f172a" style="padding:18px 20px;border-radius:14px;">
        <div style="font-size:13px;font-weight:800;color:#ffffff;margin-bottom:12px;">🤖 이번 주 핵심</div>
"@)
    foreach ($h in $highlights) {
        $line = $h
        if ($h -match '(?s)^(.*?)</strong>(.*)$') {
            $left  = $Matches[1] -replace '<strong>','<b style="color:#ffffff;">'
            $right = $Matches[2]
            $line  = "$left</b><span style=`"color:#cbd5e1;`">$right</span>"
        }
        $null = $sb.Append("        <div style=`"font-size:13px;line-height:1.65;color:#ffffff;margin-bottom:9px;`">$line</div>`r`n")
    }
    $null = $sb.Append("      </td></tr></table>`r`n  </td></tr>`r`n")
}

# 카테고리별 기사
$null = $sb.Append(@"
  <tr><td style="padding-top:18px;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#ffffff" style="border:1px solid #e2e8f0;border-radius:14px;"><tr>
      <td style="padding:6px 20px 16px;">
"@)
$first = $true
foreach ($cat in $catOrder) {
    $color = $catColors[$cat]; if (-not $color) { $color = '#334155' }
    $items = $byCat[$cat]
    $topBorder = if ($first) { '' } else { 'border-top:1px solid #f1f5f9;padding-top:14px;' }
    $first = $false
    $null = $sb.Append("        <div style=`"font-size:14px;font-weight:800;color:$color;margin:16px 0 8px;$topBorder`">$cat <span style=`"color:#cbd5e1;`">($($items.Count))</span></div>`r`n")
    foreach ($it in $items) {
        $null = $sb.Append("        <div style=`"font-size:13px;line-height:1.6;margin-bottom:7px;`">• <a href=`"$($it.Url)`" target=`"_blank`" style=`"color:#1e293b;text-decoration:none;`">$($it.Title)</a> <span style=`"color:#94a3b8;font-size:12px;`">($($it.Src))</span></div>`r`n")
    }
}
$null = $sb.Append(@"
      </td></tr></table>
  </td></tr>
  <tr><td align="center" style="padding:20px 4px 0;">
    <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin:0 auto;"><tr>
      <td bgcolor="#0f172a" style="border-radius:10px;">
        <a href="$LiveUrl" target="_blank" style="display:inline-block;padding:11px 26px;font-size:13px;font-weight:700;color:#ffffff;text-decoration:none;border-radius:10px;">전체 대시보드에서 필터·검색하기 &rarr;</a>
      </td>
    </tr></table>
    <div style="font-size:11px;color:#94a3b8;margin-top:14px;">매주 자동 갱신되는 라이브 대시보드 · COM2US IP Business Team</div>
  </td></tr>
</table>
</td></tr></table>
</div>
"@)
$htmlBody = $sb.ToString()

# ================= 텍스트 본문 =================
$tb = [System.Text.StringBuilder]::new()
$null = $tb.AppendLine("IP TREND NEWS MONITOR — LIVE DASHBOARD")
$null = $tb.AppendLine("▶ 라이브 대시보드 바로가기: $LiveUrl")
$null = $tb.AppendLine("")
$null = $tb.AppendLine("COM2US · IP BUSINESS TEAM")
$null = $tb.AppendLine($metaFull)
if ($highlights.Count) {
    $null = $tb.AppendLine(""); $null = $tb.AppendLine("[ 이번 주 핵심 ]")
    foreach ($h in $highlights) { $null = $tb.AppendLine("- " + (($h -replace '<[^>]+>','').Trim())) }
}
foreach ($cat in $catOrder) {
    $null = $tb.AppendLine(""); $null = $tb.AppendLine("[ $cat ($($byCat[$cat].Count)) ]")
    foreach ($it in $byCat[$cat]) { $null = $tb.AppendLine("- $($it.Title) ($($it.Src)) $($it.Url)") }
}
$null = $tb.AppendLine(""); $null = $tb.AppendLine("— 매주 자동 갱신되는 라이브 대시보드: $LiveUrl")
$textBody = $tb.ToString()

[pscustomobject]@{
    Subject = "[IP 트렌드] 뉴스 모니터 대시보드 — $DateTag"
    Html    = $htmlBody
    Text    = $textBody
}







