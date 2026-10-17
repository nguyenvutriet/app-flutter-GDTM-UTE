# coverage_report.ps1
# Tao bao cao HTML do phu cau lenh cho forum_service.dart tu coverage/lcov.info
#
# Cach dung (trong thu muc app_gdtm, sau khi da chay: flutter test --coverage):
#   .\coverage_report.ps1
#   start coverage\forum_service_report.html
# Neu bi chan script:
#   powershell -ExecutionPolicy Bypass -File .\coverage_report.ps1

param(
    [string]$Lcov   = "coverage/lcov.info",
    [string]$Source = "lib/services/forum_service.dart",
    [string]$Out    = "coverage/forum_service_report.html"
)

# Cac ham da kiem thu (ham private _validType/_toggle duoc test qua votePost)
$functions = @(
    '_uid', 'isAdmin', '_validType', '_toggle', 'votePost',
    'addComment', 'deleteComment', 'reportPost', 'setPostHidden',
    'getUserInfo', 'getSuggestions'
)

$src = Get-Content $Source -Encoding UTF8
$raw = Get-Content $Lcov -Raw -Encoding UTF8
$block = ($raw -split 'end_of_record') |
    Where-Object { $_ -match 'SF:.*forum_service\.dart' } |
    Select-Object -First 1
if (-not $block) { throw "Khong tim thay forum_service.dart trong $Lcov" }

# Bang: so dong -> so lan thuc thi
$hits = @{}
foreach ($m in [regex]::Matches($block, 'DA:(\d+),(\d+)')) {
    $hits[[int]$m.Groups[1].Value] = [int]$m.Groups[2].Value
}

# Tim dong bat dau va ket thuc cua mot ham (dem dau ngoac nhon)
function Get-FunctionRange([string]$name) {
    $pattern = '^  (?! )[^/]*\b' + [regex]::Escape($name) + '\b\s*[\(\{]'
    $start = -1
    for ($i = 0; $i -lt $src.Count; $i++) {
        if ($src[$i] -match $pattern -and $src[$i] -notmatch '=\s*await|return ') {
            $start = $i
            break
        }
    }
    if ($start -lt 0) { return $null }

    $depth = 0
    $opened = $false
    for ($j = $start; $j -lt $src.Count; $j++) {
        foreach ($ch in $src[$j].ToCharArray()) {
            if ($ch -eq '{') { $depth++; $opened = $true }
            elseif ($ch -eq '}') { $depth-- }
        }
        if ($opened -and $depth -le 0) { return @(($start + 1), ($j + 1)) }
    }
    return $null
}

# Thong ke theo ham
$rows = @()
$sumTotal = 0
$sumHit = 0
foreach ($fn in $functions) {
    $range = Get-FunctionRange $fn
    if ($null -eq $range) {
        Write-Warning "Khong tim thay ham $fn trong $Source"
        continue
    }
    $total = 0
    $hit = 0
    for ($n = $range[0]; $n -le $range[1]; $n++) {
        if ($hits.ContainsKey($n)) {
            $total++
            if ($hits[$n] -gt 0) { $hit++ }
        }
    }
    $sumTotal += $total
    $sumHit += $hit
    $pct = if ($total -gt 0) { 100.0 * $hit / $total } else { 100.0 }
    $rows += [pscustomobject]@{
        Name = $fn; From = $range[0]; To = $range[1]
        Total = $total; Hit = $hit; Pct = $pct
    }
}

$fileTotal = $hits.Count
$fileHit = ($hits.Values | Where-Object { $_ -gt 0 }).Count
$filePct = if ($fileTotal -gt 0) { 100.0 * $fileHit / $fileTotal } else { 0 }
$sumPct = if ($sumTotal -gt 0) { 100.0 * $sumHit / $sumTotal } else { 0 }

# Sinh HTML
$sb = New-Object System.Text.StringBuilder
$css = @'
body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#222}
h1{font-size:22px} h2{font-size:17px;margin-top:28px}
table{border-collapse:collapse;margin:8px 0}
th,td{border:1px solid #bbb;padding:5px 10px;font-size:13px}
th{background:#eee} td.num{text-align:right}
.bar{display:inline-block;height:10px;background:#d33;width:100px;vertical-align:middle}
.bar i{display:block;height:10px;background:#2a8}
pre{margin:0;font-family:Consolas,monospace;font-size:12px}
.code td{border:none;padding:0 6px;white-space:pre}
.code td.ln{color:#888;text-align:right;user-select:none}
.code td.hc{color:#666;text-align:right}
.hit{background:#e3f6e7} .miss{background:#fbdcdc} .none{background:#fff}
@media print{.code{font-size:10px}}
'@
[void]$sb.AppendLine('<!DOCTYPE html><html lang="vi"><head><meta charset="utf-8">')
[void]$sb.AppendLine('<title>Bao cao do phu ForumService</title><style>' + $css + '</style></head><body>')
[void]$sb.AppendLine('<h1>B&#225;o c&#225;o &#273;&#7897; ph&#7911; c&#226;u l&#7879;nh - forum_service.dart</h1>')
[void]$sb.AppendLine('<p>T&#7841;o l&#250;c: ' + (Get-Date -Format 'dd/MM/yyyy HH:mm') + ' &mdash; c&#244;ng c&#7909;: flutter test --coverage</p>')

[void]$sb.AppendLine('<h2>1. T&#7893;ng h&#7907;p</h2><table>')
[void]$sb.AppendLine('<tr><th>Ph&#7841;m vi</th><th>D&#242;ng th&#7921;c thi &#273;&#432;&#7907;c</th><th>&#272;&#227; ch&#7841;y</th><th>&#272;&#7897; ph&#7911;</th></tr>')
[void]$sb.AppendLine(('<tr><td>C&#225;c h&#224;m &#273;&#227; ki&#7875;m th&#7917; ({0} h&#224;m)</td><td class="num">{1}</td><td class="num">{2}</td><td class="num"><b>{3:N1}%</b></td></tr>' -f $rows.Count, $sumTotal, $sumHit, $sumPct))
[void]$sb.AppendLine(('<tr><td>To&#224;n b&#7897; file forum_service.dart</td><td class="num">{0}</td><td class="num">{1}</td><td class="num">{2:N1}%</td></tr>' -f $fileTotal, $fileHit, $filePct))
[void]$sb.AppendLine('</table>')

[void]$sb.AppendLine('<h2>2. &#272;&#7897; ph&#7911; theo h&#224;m</h2><table>')
[void]$sb.AppendLine('<tr><th>H&#224;m</th><th>D&#242;ng (t&#7915;-&#273;&#7871;n)</th><th>Th&#7921;c thi &#273;&#432;&#7907;c</th><th>&#272;&#227; ch&#7841;y</th><th>&#272;&#7897; ph&#7911;</th><th></th></tr>')
foreach ($r in $rows) {
    $w = [int][math]::Round($r.Pct)
    [void]$sb.AppendLine(('<tr><td>{0}</td><td class="num">{1}-{2}</td><td class="num">{3}</td><td class="num">{4}</td><td class="num">{5:N1}%</td><td><span class="bar"><i style="width:{6}%"></i></span></td></tr>' -f $r.Name, $r.From, $r.To, $r.Total, $r.Hit, $r.Pct, $w))
}
[void]$sb.AppendLine('</table>')

[void]$sb.AppendLine('<h2>3. M&#227; ngu&#7891;n (xanh: &#273;&#227; ch&#7841;y, &#273;&#7887;: ch&#432;a ch&#7841;y)</h2>')
[void]$sb.AppendLine('<table class="code">')
for ($i = 0; $i -lt $src.Count; $i++) {
    $n = $i + 1
    $cls = 'none'
    $cnt = ''
    if ($hits.ContainsKey($n)) {
        $cnt = $hits[$n]
        $cls = if ($hits[$n] -gt 0) { 'hit' } else { 'miss' }
    }
    $line = [System.Net.WebUtility]::HtmlEncode($src[$i])
    [void]$sb.AppendLine(('<tr class="{0}"><td class="ln">{1}</td><td class="hc">{2}</td><td>{3}</td></tr>' -f $cls, $n, $cnt, $line))
}
[void]$sb.AppendLine('</table></body></html>')

$dir = Split-Path $Out -Parent
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $Out), $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))

Write-Host ("Cac ham da kiem thu: {0}/{1} dong = {2:N1}%" -f $sumHit, $sumTotal, $sumPct)
Write-Host ("Toan file          : {0}/{1} dong = {2:N1}%" -f $fileHit, $fileTotal, $filePct)
Write-Host "Da tao: $Out"