$source = 'C:\Users\ASUS\Desktop\menubb\İBB ÖĞRENCİ YURTLARI EYLÜL 2026 ONAYLI MENÜ.xlsx'
$out = 'C:\Users\ASUS\Desktop\menubb\data\menu-org.json'

function Normalize-Cal($value) {
    $text = [string]$value
    if ([string]::IsNullOrWhiteSpace($text)) { return '' }
    $text = $text.Trim()
    if ($text -eq '') { return '' }
    $text = $text -replace '\s*kcal\b', ''
    $text = $text.Trim()
    if ($text -eq '') { return '' }
    return "$text kcal"
}

function Parse-DateText($text) {
    if ($null -eq $text) { return $null }
    $s = [string]$text
    $s = $s.Trim()
    if ($s -eq '') { return $null }

    $m = [regex]::Match($s, '(\d{1,2})[.,\s-]+([A-Za-zÇĞİÖŞÜçğıöşü]+)[,\s-]+(\d{4})')
    if (-not $m.Success) { return $null }

    $day = [int]$m.Groups[1].Value
    $monthText = $m.Groups[2].Value.Trim().ToLowerInvariant()
    $monthMap = @{
        'ocak'='01'; 'şubat'='02'; 'subat'='02'; 'mart'='03'; 'nisan'='04'; 'mayis'='05'; 'haziran'='06'; 'temmuz'='07'; 'agustos'='08'; 'eylul'='09'; 'eylül'='09'; 'ekim'='10'; 'kasim'='11'; 'aralik'='12'
    }

    if (-not $monthMap.ContainsKey($monthText)) { return $null }
    $year = [int]$m.Groups[3].Value
    return '{0}-{1}-{2}' -f $year, $monthMap[$monthText], $day.ToString('00')
}

$menuData = [ordered]@{}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open($source)

foreach ($ws in $wb.Worksheets) {
    $sheetName = [string]$ws.Name
    $upper = $sheetName.ToUpperInvariant()

    for ($r = 1; $r -le $ws.UsedRange.Rows.Count; $r++) {
        for ($c = 1; $c -le $ws.UsedRange.Columns.Count; $c++) {
            $cellText = [string]$ws.Cells.Item($r, $c).Text
            $dateKey = Parse-DateText $cellText
            if (-not $dateKey) { continue }

            if ($upper.Contains('AKŞAM') -or $upper.Contains('AKSAM')) {
                if (-not $menuData.Contains($dateKey)) {
                    $menuData[$dateKey] = [ordered]@{ kahvalti = @(); aksam = @() }
                }

                $items = @()
                for ($rr = 7; $rr -le 11; $rr++) {
                    $mainName = [string]$ws.Cells.Item($rr, $c).Text
                    if (-not [string]::IsNullOrWhiteSpace($mainName) -and $mainName.Trim().ToUpperInvariant() -ne 'TOPLAM') {
                        $mainCal = Normalize-Cal([string]$ws.Cells.Item($rr, $c + 1).Text)
                        $items += [ordered]@{ category = 'Ana Menü'; name = $mainName.Trim(); calories = $mainCal }
                    }

                    $saladName = [string]$ws.Cells.Item($rr, $c + 2).Text
                    if (-not [string]::IsNullOrWhiteSpace($saladName) -and $saladName.Trim().ToUpperInvariant() -ne 'TOPLAM') {
                        $saladCal = Normalize-Cal([string]$ws.Cells.Item($rr, $c + 3).Text)
                        $items += [ordered]@{ category = 'Salatbar'; name = $saladName.Trim(); calories = $saladCal }
                    }
                }

                if ($items.Count -gt 0) {
                    $menuData[$dateKey].aksam = @($items)
                }
            }
            elseif ($upper.Contains('KAHVALTI')) {
                if (-not $menuData.Contains($dateKey)) {
                    $menuData[$dateKey] = [ordered]@{ kahvalti = @(); aksam = @() }
                }

                $items = @()
                for ($rr = ($r + 2); $rr -le ($r + 8); $rr++) {
                    $name = [string]$ws.Cells.Item($rr, $c).Text
                    if ([string]::IsNullOrWhiteSpace($name)) { continue }
                    $up = $name.Trim().ToUpperInvariant()
                    if ($up -eq 'TOPLAM' -or $up.StartsWith('ALERJEN') -or $up.StartsWith('YEMEKHANEDE')) { break }
                    $cal = Normalize-Cal([string]$ws.Cells.Item($rr, $c + 1).Text)
                    $items += [ordered]@{ category = 'Kahvaltılık'; name = $name.Trim(); calories = $cal }
                }

                if ($items.Count -gt 0) {
                    $menuData[$dateKey].kahvalti = @($items)
                }
            }
        }
    }
}

$wb.Close($false)
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

$sorted = [ordered]@{}
foreach ($key in ($menuData.Keys | Sort-Object)) {
    $sorted[$key] = $menuData[$key]
}

$sorted | ConvertTo-Json -Depth 20 | Out-File -Encoding utf8 $out
Write-Host "Wrote $out with $($sorted.Count) dates."
