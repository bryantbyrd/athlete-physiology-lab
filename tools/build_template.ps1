<#
.SYNOPSIS
    Build a clean workbook template from a working analysis workbook.

.DESCRIPTION
    Drives Excel (Windows, Microsoft 365) on a COPY of the working workbook:

      1. copies the source workbook to a scratch folder (the source is only read);
      2. opens the copy with macros and events disabled;
      3. adds the DataFolder parameter and replaces both data queries with the
         parameterised versions in excel/power-query/;
      4. renames queries, query tables and connections to hr_stream / rr_stream,
         removing the sensor ID from every object name;
      5. refreshes both queries from SYNTHETIC hr.csv / rr.csv, so all cached
         cell values and chart caches hold synthetic data;
      6. applies the template design corrections (time-zone table, #N/A for
         unavailable rolling means, chart and label fixes) if the working
         workbook does not already have them;
      7. deletes every row of the nightly log;
      8. resets DataFolder to a neutral placeholder path;
      9. removes document properties and saves the result.

    The saved file is NOT yet publishable: Excel records the folder it saved to
    and may keep printer settings. Run tools/scrub_workbook.py on the output,
    then tools/audit_workbook.py on the scrubbed file.

.PARAMETER Source
    Working workbook (.xlsm). Never opened directly; never modified.

.PARAMETER DataFolder
    Folder containing synthetic hr.csv and rr.csv
    (see tools/make_synthetic_night.py).

.PARAMETER Output
    Path for the unscrubbed template (.xlsm). Write it outside the repository.

.PARAMETER WorkDir
    Scratch folder for the working copy. Defaults to a folder under %TEMP%.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_template.ps1 `
        -Source "D:\private\My Workbook.xlsm" `
        -DataFolder "D:\scratch\synthetic" `
        -Output "D:\scratch\template-raw.xlsm"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$DataFolder,
    [Parameter(Mandatory = $true)][string]$Output,
    [string]$WorkDir = (Join-Path $env:TEMP 'apl-template-build')
)

$ErrorActionPreference = 'Stop'

# --- Inputs ------------------------------------------------------------------

$repo = Split-Path $PSScriptRoot -Parent
$pqDir = Join-Path $repo 'excel\power-query'

$Source = (Resolve-Path -LiteralPath $Source).Path
$DataFolder = (Resolve-Path -LiteralPath $DataFolder).Path.TrimEnd('\') + '\'
foreach ($name in 'hr.csv', 'rr.csv') {
    if (-not (Test-Path -LiteralPath (Join-Path $DataFolder $name))) {
        throw "Synthetic data file not found: $name in $DataFolder"
    }
}
$Output = [IO.Path]::GetFullPath($Output)
if ($Output -eq $Source) { throw 'Output must not be the source workbook.' }

# Load a query's M source without its leading comment block.
function Read-Query([string]$name) {
    $lines = Get-Content -LiteralPath (Join-Path $pqDir $name) -Encoding UTF8
    $first = 0
    while ($first -lt $lines.Count -and ($lines[$first] -match '^\s*(//.*)?$')) { $first++ }
    return (($lines[$first..($lines.Count - 1)]) -join "`r`n").TrimEnd()
}
$mHr = Read-Query 'hr_stream.pq'
$mRr = Read-Query 'rr_stream.pq'
$mPlaceholder = Read-Query 'DataFolder.pq'
$paramMeta = 'meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]'
$mBuildFolder = '"' + $DataFolder.Replace('"', '""') + '" ' + $paramMeta

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$copy = Join-Path $WorkDir 'template_build.xlsm'
Copy-Item -LiteralPath $Source -Destination $copy -Force
(Get-Item -LiteralPath $copy).IsReadOnly = $false
Write-Host "Working on a copy: $copy"

# --- Template design changes ---------------------------------------------------
#
# Corrections that exist in the template but not (yet) in the working workbook.
# Every step checks whether it has already been applied, so the function is a
# no-op once the working workbook has been updated by hand.
#
#   1. Time zone: recordings are identified by their UTC start time. Local
#      dates come from a table of dated UTC offsets on a Settings sheet
#      instead of a fixed offset inside a formula.
#   2. Rolling means return #N/A, not "", when unavailable, so line charts
#      leave a gap instead of plotting zero.
#   3. The screened-RMSSD trend chart shows RMSSD only (the lnRMSSD rolling
#      means are on a different scale and belong to the lnRMSSD chart).
#   4. "lnRMSSD" is spelled with a lowercase L in every chart label.
#   5. Chart value axes scale automatically. Fixed bounds chosen for one
#      person's values hide other data and hint at that person's range.

function Update-TemplateDesign($xl, $wb) {
    $missing = [System.Reflection.Missing]::Value
    $utcHeader = 'Recording start (UTC)'
    $localHeader = 'Recording date (local)'
    $offsetHeader = 'UTC offset (h)'
    $lookup = 'XLOOKUP({0},TimeZone[Effective from (UTC)],TimeZone[UTC offset (h)],0,-1)'

    # --- 1a. Settings sheet with the TimeZone table ----------------------------
    $settings = $null
    foreach ($ws in @($wb.Worksheets)) { if ($ws.Name -eq 'Settings') { $settings = $ws } }
    if (-not $settings) {
        $settings = $wb.Worksheets.Add($missing, $wb.Worksheets.Item($wb.Worksheets.Count))
        $settings.Name = 'Settings'
        $settings.Range('A1').Value2 = 'Time zone'
        $settings.Range('A1').Font.Bold = $true
        $settings.Range('A1').Font.Size = 14
        $notes = @(
            'Recordings are identified by their start time in UTC. Local dates are derived from the table below.',
            'Local time = UTC + offset. Offsets are in hours: negative west of Greenwich (for example -7), positive east (for example 5.5).',
            'Each row applies from its "Effective from (UTC)" time until the next row begins.',
            'Add a row whenever your offset changes (daylight-saving time, travel). Past nights keep the offset that was in effect.',
            'Editing this table never changes how recordings are identified or how duplicates are detected.'
        )
        for ($i = 0; $i -lt $notes.Count; $i++) { $settings.Cells.Item($i + 2, 1).Value2 = $notes[$i] }
        $settings.Range('A9').Value2 = 'Effective from (UTC)'
        $settings.Range('B9').Value2 = $offsetHeader
        $settings.Range('C9').Value2 = 'Note'
        $settings.Range('A10').Value2 = 25569      # 1970-01-01 00:00
        $settings.Range('B10').Value2 = 0
        $settings.Range('C10').Value2 = 'Default: local dates are shown in UTC. Replace 0 with your own offset.'
        $tz = $settings.ListObjects.Add(1, $settings.Range('A9:C10'), $missing, 1)
        $tz.Name = 'TimeZone'
        $tz.ListColumns.Item(1).Range.NumberFormat = 'yyyy-mm-dd hh:mm'
        $tz.ListColumns.Item(2).Range.NumberFormat = '0.##'
        $settings.Columns.Item(1).ColumnWidth = 24
        $settings.Columns.Item(2).ColumnWidth = 16
        $settings.Columns.Item(3).ColumnWidth = 70
        Write-Host '  design: added Settings sheet with TimeZone table'
    }

    # --- 1b. Whole-night summary: UTC start, local date, offset ----------------
    $summary = $wb.Worksheets.Item('HRV Analysis')
    if ([string]$summary.Range('A2').Formula -match 'TIME\(' -or [string]$summary.Range('P1').Value2 -ne $localHeader) {
        $summary.Range('A1').Value2 = $utcHeader
        $summary.Range('A2').Formula = '=DATE(1970,1,1)+MIN(HR!A:A)/86400000'
        $summary.Range('P1').Value2 = $localHeader
        $summary.Range('P2').Formula2 = '=A2+' + ($lookup -f 'A2') + '/24'
        $summary.Range('Q1').Value2 = $offsetHeader
        $summary.Range('Q2').Formula2 = '=' + ($lookup -f 'A2')
        $summary.Range('P2').NumberFormat = $summary.Range('A2').NumberFormat
        foreach ($cell in 'P1', 'Q1') {
            $summary.Range($cell).Font.Bold = $summary.Range('A1').Font.Bold
            $summary.Range($cell).HorizontalAlignment = $summary.Range('A1').HorizontalAlignment
            $summary.Range($cell).WrapText = $summary.Range('A1').WrapText
        }
        $summary.Columns.Item(16).ColumnWidth = $summary.Columns.Item(1).ColumnWidth
        $summary.Columns.Item(17).ColumnWidth = 14
        Write-Host '  design: summary now holds UTC start, local date and UTC offset'
    }

    $dash = $wb.Worksheets.Item('Dashboard')
    if ([string]$dash.Range('B2').Formula -match "'HRV Analysis'!\`$?A\`$?2") {
        $dash.Range('B2').Formula = "='HRV Analysis'!P2"
        $dash.Range('A2').Value2 = 'Recording date (local)'
        Write-Host '  design: dashboard shows the local recording date'
    }

    # --- 1c. Nightly log: UTC identifier in column 1, derived local date -------
    $logSheet = $wb.Worksheets.Item('Nightly Log')
    $log = $logSheet.ListObjects.Item(1)
    if ($log.ListRows.Count -eq 0) { [void]$log.ListRows.Add() }   # formulas need a row
    $first = $log.ListColumns.Item(1)
    if ($first.Name -ne $utcHeader) { $first.Name = $utcHeader }
    $existing = @($log.ListColumns | ForEach-Object { $_.Name })
    $rowRef = "[@[$utcHeader]]"
    if ($existing -notcontains $localHeader) {
        $col = $log.ListColumns.Add()
        $col.Name = $localHeader
        $col.DataBodyRange.Formula2 = "=$rowRef+" + ($lookup -f $rowRef) + '/24'
        $col.DataBodyRange.NumberFormat = $first.DataBodyRange.NumberFormat
        $col.Range.ColumnWidth = $first.Range.ColumnWidth
    }
    if ($existing -notcontains $offsetHeader) {
        $col = $log.ListColumns.Add()
        $col.Name = $offsetHeader
        $col.DataBodyRange.Formula2 = '=' + ($lookup -f $rowRef)
        $col.DataBodyRange.NumberFormat = '0.##'
    }
    $wb.Names.Item('LogDate').RefersTo = "=Nightlog[$localHeader]"
    Write-Host '  design: nightly log keyed on UTC start; local date and offset derived'

    # --- 2. Rolling means: #N/A instead of "" ----------------------------------
    $changed = 0
    foreach ($col in @($log.ListColumns)) {
        if ($col.Name -notmatch '^(7|28)-night ') { continue }
        $formula = [string]$col.DataBodyRange.Cells.Item(1, 1).Formula2
        if ($formula -match '""') {
            $col.DataBodyRange.Formula2 = $formula.Replace('""', 'NA()')
            $changed++
        }
    }
    if ($changed) { Write-Host "  design: $changed rolling-mean columns now return #N/A when unavailable" }

    # --- 3 and 4. Charts ----------------------------------------------------------
    foreach ($ws in @($wb.Worksheets)) {
        foreach ($co in @($ws.ChartObjects())) {
            $chart = $co.Chart
            $count = $chart.SeriesCollection().Count
            if ($count -gt 1 -and [string]$chart.SeriesCollection(1).Formula -match '!LogRMSSD\b') {
                for ($i = $count; $i -ge 2; $i--) {
                    $series = $chart.SeriesCollection($i)
                    if ([string]$series.Formula -match 'LogLnRMSSD') {
                        [void]$series.Delete()
                        Write-Host "  design: removed an lnRMSSD rolling mean from the RMSSD chart on '$($ws.Name)'"
                    }
                }
            }
            $titles = @()
            if ($chart.HasTitle) { $titles += $chart.ChartTitle }
            foreach ($axisType in 1, 2) {
                try { $axis = $chart.Axes($axisType); if ($axis.HasTitle) { $titles += $axis.AxisTitle } } catch { }
            }
            foreach ($title in $titles) {
                $text = [string]$title.Text
                $at = $text.IndexOf('InRMSSD', [StringComparison]::Ordinal)
                while ($at -ge 0) {
                    try { $title.Characters($at + 1, 1).Text = 'l' }
                    catch { $title.Text = $text.Replace('InRMSSD', 'lnRMSSD') }
                    $text = [string]$title.Text
                    $at = $text.IndexOf('InRMSSD', [StringComparison]::Ordinal)
                    Write-Host "  design: corrected an lnRMSSD label on '$($ws.Name)'"
                }
            }
            try {
                $valueAxis = $chart.Axes(2)
                $freed = $false
                if (-not $valueAxis.MinimumScaleIsAuto -and $valueAxis.MinimumScale -ne 0) { $valueAxis.MinimumScaleIsAuto = $true; $freed = $true }
                if (-not $valueAxis.MaximumScaleIsAuto) { $valueAxis.MaximumScaleIsAuto = $true; $freed = $true }
                if ($freed) { Write-Host "  design: value axis set to automatic scaling on a chart on '$($ws.Name)'" }
            } catch { }
            for ($i = 1; $i -le $chart.SeriesCollection().Count; $i++) {
                $series = $chart.SeriesCollection($i)
                if ([string]$series.Name -cmatch 'InRMSSD') { $series.Name = ([string]$series.Name) -creplace 'InRMSSD', 'lnRMSSD' }
            }
        }
    }
}

# Grey out "#N/A" in the rolling-mean columns (shown until enough nights exist).
function Set-RollingMeanFormat($wb) {
    $missing = [System.Reflection.Missing]::Value
    $sheet = $wb.Worksheets.Item('Nightly Log')
    $log = $sheet.ListObjects.Item(1)
    foreach ($col in @($log.ListColumns)) {
        if ($col.Name -notmatch '^(7|28)-night ') { continue }
        $index = $col.Range.Column
        $range = $sheet.Range($sheet.Cells.Item(2, $index), $sheet.Cells.Item(5000, $index))
        if ($range.FormatConditions.Count -gt 0) { continue }
        $topCell = ([string]$sheet.Cells.Item(2, $index).Address($false, $false))
        $rule = $range.FormatConditions.Add(2, $missing, "=ISNA($topCell)")
        $rule.Font.Color = 10921638     # RGB(166,166,166)
    }
}

# --- Excel -------------------------------------------------------------------

Add-Type -Namespace Apl -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
'@

$xl = New-Object -ComObject Excel.Application
$excelPid = 0
[void][Apl.Native]::GetWindowThreadProcessId([IntPtr]$xl.Hwnd, [ref]$excelPid)
$wb = $null

try {
    $xl.Visible = $false
    $xl.DisplayAlerts = $false
    $xl.AskToUpdateLinks = $false
    $xl.EnableEvents = $false
    $xl.AutomationSecurity = 3          # msoAutomationSecurityForceDisable: no macros run

    $wb = $xl.Workbooks.Open($copy, 0, $false)
    $wb.Queries.FastCombine = $true     # this session only: no privacy-level prompt

    # --- Queries ---------------------------------------------------------------
    $targets = @{ 'rr_stream' = $mRr; 'hr_stream' = $mHr }
    $renamed = @{}
    foreach ($q in @($wb.Queries)) {
        $new = $null
        if ($q.Name -match '(?i)(^|_)rr(_stream)?$') { $new = 'rr_stream' }
        elseif ($q.Name -match '(?i)(^|_)hr(_stream)?$') { $new = 'hr_stream' }
        if ($new) {
            $old = $q.Name
            if ($old -ne $new) { $q.Name = $new }
            $renamed[$old] = $new
        }
    }
    if ($renamed.Count -ne 2) { throw "Expected one HR and one RR query; matched $($renamed.Count)." }

    $hasParam = $false
    foreach ($q in @($wb.Queries)) { if ($q.Name -eq 'DataFolder') { $hasParam = $true } }
    if ($hasParam) { $wb.Queries.Item('DataFolder').Formula = $mBuildFolder }
    else { [void]$wb.Queries.Add('DataFolder', $mBuildFolder) }

    foreach ($name in $targets.Keys) { $wb.Queries.Item($name).Formula = $targets[$name] }

    # --- Connections -----------------------------------------------------------
    foreach ($c in @($wb.Connections)) {
        foreach ($old in $renamed.Keys) {
            $new = $renamed[$old]
            if ($old -eq $new) { continue }
            if ($c.Name -notmatch [regex]::Escape($old)) { continue }
            $o = $c.OLEDBConnection
            $connString = [string]$o.Connection
            if ($connString -match [regex]::Escape($old)) {
                $o.Connection = $connString.Replace("Location=$old", "Location=$new")
            }
            $command = (@($o.CommandText) -join '')
            if ($command -match [regex]::Escape($old)) {
                $o.CommandText = "SELECT * FROM [$new]"
            }
            $c.Name = "Query - $new"
            $c.Description = "Connection to the '$new' query in the workbook."
        }
    }

    # --- Query tables ----------------------------------------------------------
    $tables = @{ 'RR' = 'rr_stream'; 'HR' = 'hr_stream' }
    foreach ($sheet in $tables.Keys) {
        $lo = $wb.Worksheets.Item($sheet).ListObjects.Item(1)
        if ($lo.Name -ne $tables[$sheet]) { $lo.Name = $tables[$sheet] }
    }

    # --- Refresh from synthetic data -------------------------------------------
    foreach ($sheet in 'HR', 'RR') {
        $lo = $wb.Worksheets.Item($sheet).ListObjects.Item(1)
        if (-not $lo.QueryTable.Refresh($false)) { throw "Refresh failed for sheet $sheet." }
        Write-Host ("  {0}: {1} rows after refresh" -f $sheet, $lo.ListRows.Count)
    }
    $xl.CalculateUntilAsyncQueriesDone()
    $xl.CalculateFull()

    # --- Design corrections (see Update-TemplateDesign above) ------------------
    Update-TemplateDesign $xl $wb
    $xl.CalculateFull()

    # --- Empty the nightly log -------------------------------------------------
    $log = $wb.Worksheets.Item('Nightly Log').ListObjects.Item(1)
    $removed = $log.ListRows.Count
    while ($log.ListRows.Count -gt 0) { $log.ListRows.Item($log.ListRows.Count).Delete() }
    Write-Host "  Nightly Log: removed $removed row(s)"
    Set-RollingMeanFormat $wb

    # --- Neutral parameter value; nothing is refreshed after this ---------------
    $wb.Queries.Item('DataFolder').Formula = $mPlaceholder
    $xl.CalculateFull()

    # --- Document information --------------------------------------------------
    $wb.RemoveDocumentInformation(8)    # xlRDIDocumentProperties
    $wb.RemoveDocumentInformation(4)    # xlRDIRemovePersonalInformation
    try { $wb.RemoveDocumentInformation(20) } catch { }   # xlRDIPrinterPath
    $wb.RemovePersonalInformation = $true

    $wb.Worksheets.Item('Dashboard').Activate()
    $wb.Worksheets.Item('Dashboard').Range('A1').Select() | Out-Null

    # --- Report (synthetic values) ----------------------------------------------
    $summary = $wb.Worksheets.Item('HRV Analysis')
    Write-Host '  Whole-night summary of the synthetic recording:'
    for ($col = 1; $col -le 17; $col++) {
        Write-Host ("    {0,-28} {1}" -f $summary.Cells.Item(1, $col).Text, $summary.Cells.Item(2, $col).Text)
    }
    Write-Host '  Objects:'
    foreach ($q in @($wb.Queries)) { Write-Host "    query       $($q.Name)" }
    foreach ($c in @($wb.Connections)) { Write-Host "    connection  $($c.Name)" }

    New-Item -ItemType Directory -Force -Path (Split-Path $Output -Parent) | Out-Null
    $wb.SaveAs($Output, 52)             # xlOpenXMLWorkbookMacroEnabled
    Write-Host "Saved (unscrubbed): $Output"
}
finally {
    if ($wb) { try { $wb.Close($false) } catch { } }
    try { $xl.Quit() } catch { }
    if ($wb) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($wb) }
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    # Stop only the Excel instance this script started, if it is still alive.
    if ($excelPid) {
        Start-Sleep -Seconds 3
        $proc = Get-Process -Id $excelPid -ErrorAction SilentlyContinue
        if ($proc -and $proc.ProcessName -eq 'EXCEL') { Stop-Process -Id $excelPid -Force }
    }
    Remove-Item -LiteralPath $copy -Force -ErrorAction SilentlyContinue
}

Write-Host 'Next: python tools\scrub_workbook.py <output> <final>, then tools\audit_workbook.py <final>.'
