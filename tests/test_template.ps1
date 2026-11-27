<#
.SYNOPSIS
    Functional test of the workbook template and its RefreshAndSaveNight macro.

.DESCRIPTION
    Works on a DISPOSABLE COPY of the template with SYNTHETIC recordings only.
    The template in the repository is never opened or modified, and no real
    recording is read.

    The test generates a series of synthetic nights, then for each one stages
    hr.csv / rr.csv and runs the workbook's own RefreshAndSaveNight macro, as
    pressing the dashboard button would. It checks that:

      * a new recording adds one row to the nightly log;
      * re-importing a recording never adds a duplicate row;
      * manually entered context fields survive a re-import;
      * recordings are identified by their UTC start time, and local dates
        follow the TimeZone table (including a mid-series offset change);
      * 7- and 28-night rolling means are #N/A until enough nights exist and
        afterwards equal an independently computed mean;
      * the trend charts and their named ranges grow with the log, contain
        the expected series, show every value within their axes, and never
        plot an unavailable mean as zero.

    Requirements: Windows, Microsoft Excel (Microsoft 365), Python 3.

    Excel can crash while refreshing this workbook (see "Known issue" in
    excel/README.md). The disposable copy is therefore saved after each step;
    if Excel dies it is restarted and the step retried, and the number of
    failures is reported at the end. Functional checks are not affected.

    Macros are enabled only inside the Excel instance this script starts.
    The macro reports through message boxes; a helper closes them and records
    their text, so a dialog may flash on screen while the test runs.

.PARAMETER Template
    Template to test. Default: excel\template\athlete-recovery-template.xlsm.

.PARAMETER Nights
    Number of synthetic nights (default 30; at least 29 to exercise the
    28-night mean).

.PARAMETER WorkDir
    Scratch folder. Deleted at the end unless -KeepWork is given.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tests\test_template.ps1
#>
[CmdletBinding()]
param(
    [string]$Template,
    [int]$Nights = 30,
    [string]$WorkDir = (Join-Path $env:TEMP 'apl-template-test'),
    [switch]$KeepWork
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $Template) { $Template = Join-Path $repo 'excel\template\athlete-recovery-template.xlsm' }
$Template = (Resolve-Path -LiteralPath $Template).Path
if ($Nights -lt 29) { throw 'Use at least 29 nights so the 28-night mean is exercised.' }

$script:passed = 0
$script:failed = 0
function Check([string]$what, [bool]$ok, [string]$detail = '') {
    if ($ok) { $script:passed++; Write-Host "ok    $what" }
    else { $script:failed++; Write-Host "FAIL  $what  $detail" }
}

# --- Scratch area and synthetic nights -------------------------------------------

if (Test-Path -LiteralPath $WorkDir) { Remove-Item -LiteralPath $WorkDir -Recurse -Force }
$synDir = Join-Path $WorkDir 'syn'
$current = Join-Path $WorkDir 'current'
$chartDir = Join-Path $WorkDir 'charts'
New-Item -ItemType Directory -Force -Path $synDir, $current, $chartDir | Out-Null

$templateHash = (Get-FileHash -LiteralPath $Template -Algorithm SHA256).Hash
$copy = Join-Path $WorkDir 'disposable-copy.xlsm'
Copy-Item -LiteralPath $Template -Destination $copy
(Get-Item -LiteralPath $copy).IsReadOnly = $false

$sensor = '00000000'
$firstNight = [datetime]::SpecifyKind([datetime]'2021-03-01T05:00:00', 'Utc')
$epoch = [datetime]::SpecifyKind([datetime]'1970-01-01T00:00:00', 'Utc')
# Offset change part-way through the series (as at a daylight-saving switch).
$switchUtc = [datetime]::SpecifyKind([datetime]'2021-03-14T09:00:00', 'Utc')
$offsetBefore = -7
$offsetAfter = -6

function Get-Serial([datetime]$utc) { return 25569 + ($utc - $epoch).TotalDays }

$nightStart = @{}
$nightFolder = @{}
Write-Host "Generating $Nights synthetic nights..."
for ($i = 1; $i -le $Nights; $i++) {
    $start = $firstNight.AddDays($i - 1)
    $nightStart[$i] = $start
    $iso = $start.ToString('yyyy-MM-ddTHH:mm:ss')
    $seed = 100 + $i
    $null = & python -I (Join-Path $repo 'tools\make_synthetic_night.py') --out $synDir --hours 1 --seed $seed --start $iso
    if ($LASTEXITCODE -ne 0) { throw "Synthetic generator failed for night $i" }
    $nightFolder[$i] = Join-Path $synDir ('SF_{0}_Polar-H10-{1}' -f $start.ToString('yyyyMMdd-HHmmss'), $sensor)
}

# --- Helper that closes the macro's message boxes and records their text ----------

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace Apl {
    public static class DialogWatcher {
        private delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
        [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr lParam);
        [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr lParam);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr hWnd, StringBuilder text, int max);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, StringBuilder lParam);
        [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")] private static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

        private static readonly object Gate = new object();
        private static readonly List<string> Seen = new List<string>();
        private static Thread worker;
        private static volatile bool running;
        private static uint target;
        private static IntPtr lastWindow = IntPtr.Zero;
        private static DateTime lastTime = DateTime.MinValue;

        public static uint ProcessIdOf(IntPtr hWnd) { uint pid; GetWindowThreadProcessId(hWnd, out pid); return pid; }

        public static void Start(uint processId) {
            target = processId; running = true;
            worker = new Thread(Loop); worker.IsBackground = true; worker.Start();
        }

        public static void Stop() { running = false; if (worker != null) worker.Join(2000); }

        public static string[] TakeMessages() {
            lock (Gate) { string[] copy = Seen.ToArray(); Seen.Clear(); return copy; }
        }

        private static string ClassOf(IntPtr h) { StringBuilder sb = new StringBuilder(256); GetClassName(h, sb, 256); return sb.ToString(); }

        private static void Loop() {
            while (running) {
                EnumWindows(delegate(IntPtr h, IntPtr l) {
                    uint pid; GetWindowThreadProcessId(h, out pid);
                    if (pid != target || !IsWindowVisible(h) || ClassOf(h) != "#32770") return true;
                    if (h == lastWindow && (DateTime.UtcNow - lastTime).TotalSeconds < 2) return true;
                    List<string> parts = new List<string>();
                    EnumChildWindows(h, delegate(IntPtr c, IntPtr l2) {
                        if (ClassOf(c) == "Static") {
                            StringBuilder sb = new StringBuilder(2048);
                            SendMessage(c, 0x000D, (IntPtr)2048, sb);
                            if (sb.Length > 0) parts.Add(sb.ToString());
                        }
                        return true;
                    }, IntPtr.Zero);
                    lock (Gate) { Seen.Add(string.Join(" ", parts.ToArray())); }
                    lastWindow = h; lastTime = DateTime.UtcNow;
                    PostMessage(h, 0x0010, IntPtr.Zero, IntPtr.Zero);   // WM_CLOSE
                    return true;
                }, IntPtr.Zero);
                Thread.Sleep(100);
            }
        }
    }
}
'@

# --- Excel ---------------------------------------------------------------------------

$naCode = -2146826246     # how COM reports #N/A
function Test-NA($value) { return ($value -is [int] -and $value -eq $naCode) }

function Get-ColumnValues($log, $column) {
    $count = $log.ListRows.Count
    $values = New-Object object[] $count
    if ($count -eq 0) { return , $values }
    $range = $log.ListColumns.Item($column).DataBodyRange
    if ($count -eq 1) { $values[0] = $range.Value2; return , $values }
    $raw = $range.Value2
    for ($r = 1; $r -le $count; $r++) { $values[$r - 1] = $raw[$r, 1] }
    return , $values
}

$success = 'Nightly recording saved successfully.'
$excelBefore = @(Get-Process excel -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
$xl = $null; $wb = $null; $log = $null; $tz = $null; $excelPid = 0; $macro = ''
$script:macroRuns = 0
$script:excelFailures = 0

# Excel can crash while refreshing this workbook (see "Known issue" in
# excel\README.md). To finish the functional checks regardless, the disposable
# copy is saved after every successful step; if Excel dies, it is restarted,
# the copy reopened and the step retried. Failures are counted and reported.

function Start-TestExcel {
    $script:xl = New-Object -ComObject Excel.Application
    $script:excelPid = [Apl.DialogWatcher]::ProcessIdOf([IntPtr]$script:xl.Hwnd)
    $script:xl.Visible = $false
    $script:xl.DisplayAlerts = $false
    $script:xl.AskToUpdateLinks = $false
    $script:xl.AutomationSecurity = 1          # macros enabled in this instance only
    $script:wb = $script:xl.Workbooks.Open($copy, 0, $false)
    $script:wb.Queries.FastCombine = $true
    $script:macro = "'" + $script:wb.Name + "'!RefreshAndSaveNight"
    $script:log = $script:wb.Worksheets.Item('Nightly Log').ListObjects.Item(1)
    $script:tz = $script:wb.Worksheets.Item('Settings').ListObjects.Item('TimeZone')
    [Apl.DialogWatcher]::Start($script:excelPid)
}

function Stop-TestExcel {
    [Apl.DialogWatcher]::Stop()
    if ($script:wb) { try { $script:wb.Close($false) } catch { } }
    if ($script:xl) {
        try { $script:xl.Quit() } catch { }
        try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($script:xl) } catch { }
    }
    $script:wb = $null; $script:xl = $null; $script:log = $null; $script:tz = $null
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    Start-Sleep -Seconds 2
    if ($script:excelPid) {
        $proc = Get-Process -Id $script:excelPid -ErrorAction SilentlyContinue
        if ($proc -and $proc.ProcessName -eq 'EXCEL') { Stop-Process -Id $script:excelPid -Force }
    }
    # After a crash Windows may relaunch Excel, hidden, to offer document
    # recovery. Stop only instances that appeared during this test and show
    # no window; never one that was already running.
    Start-Sleep -Seconds 3
    Get-Process excel -ErrorAction SilentlyContinue |
        Where-Object { $excelBefore -notcontains $_.Id -and $_.MainWindowTitle -eq '' } |
        ForEach-Object { Stop-Process -Id $_.Id -Force }
    Start-Sleep -Seconds 1
    Get-ChildItem -LiteralPath $WorkDir -Filter '~$*' -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Save-State { $script:wb.Save() }

function Import-Night([int]$i) {
    Copy-Item -LiteralPath (Join-Path $nightFolder[$i] "${sensor}_hr.csv") -Destination (Join-Path $current 'hr.csv') -Force
    Copy-Item -LiteralPath (Join-Path $nightFolder[$i] "${sensor}_rr.csv") -Destination (Join-Path $current 'rr.csv') -Force
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        $script:macroRuns++
        $failure = $null
        $message = ''
        [void][Apl.DialogWatcher]::TakeMessages()
        try {
            [void]$script:xl.Run($script:macro)
            Start-Sleep -Milliseconds 150
            $message = (@([Apl.DialogWatcher]::TakeMessages()) -join ' | ')
            $null = $script:log.ListRows.Count          # fails if Excel has died
            if ($message -ne $success) { $failure = "macro reported: $message" }
        }
        catch {
            $inner = $_.Exception
            while ($inner.InnerException) { $inner = $inner.InnerException }
            $failure = $inner.Message
        }
        if (-not $failure) { Save-State; return $message }
        $script:excelFailures++
        Write-Host "      night ${i}, attempt ${attempt}: Excel failed during the refresh ($failure). Restarting Excel and retrying."
        Stop-TestExcel
        Start-TestExcel
    }
    throw "Night $i could not be imported after 5 attempts."
}

try {
    Start-TestExcel
    $wb.Queries.Item('DataFolder').Formula = '"' + $current + '\" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]'

    # Time-zone table: one offset from the start, another after the switch.
    $tz.DataBodyRange.Cells.Item(1, 2).Value2 = $offsetBefore
    $row = $tz.ListRows.Add()
    $row.Range.Cells.Item(1, 1).Value2 = [double](Get-Serial $switchUtc)
    $row.Range.Cells.Item(1, 2).Value2 = $offsetAfter
    $row.Range.Cells.Item(1, 3).Value2 = 'test: offset change'
    Save-State

    Write-Host ''
    Write-Host '--- New recording, duplicate prevention, manual notes ---'
    Check 'template opens with an empty nightly log' ($log.ListRows.Count -eq 0) "rows=$($log.ListRows.Count)"

    $message = Import-Night 1
    Check 'macro reports success for the first recording' ($message -eq $success) "message='$message'"
    Check 'a new recording creates one nightly-log entry' ($log.ListRows.Count -eq 1) "rows=$($log.ListRows.Count)"

    $measuredCols = @(1..12) + @(28..30)
    $before = @{}
    foreach ($c in $measuredCols) { $before[$c] = $log.DataBodyRange.Cells.Item(1, $c).Value2 }
    $filled = @($measuredCols | Where-Object { $before[$_] -is [double] }).Count
    Check 'all 15 measured values are stored as numbers' ($filled -eq 15) "numeric=$filled"

    # Manual context fields are columns 13-23 (bedtime ... notes).
    $manual = @('22:15', '06:05', 'Run', 45, 'Moderate', '18:30', '13:00', 7, 4, 1600, 'synthetic test note - keep me')
    for ($k = 0; $k -lt $manual.Count; $k++) {
        $cell = $log.DataBodyRange.Cells.Item(1, 13 + $k)
        if ($manual[$k] -is [string]) { $cell.Value2 = [string]$manual[$k] } else { $cell.Value2 = [double]$manual[$k] }
    }
    $manualBefore = @(); for ($k = 0; $k -lt $manual.Count; $k++) { $manualBefore += , $log.DataBodyRange.Cells.Item(1, 13 + $k).Value2 }
    Save-State

    $message = Import-Night 2
    Check 'a second recording adds a second entry' ($log.ListRows.Count -eq 2) "rows=$($log.ListRows.Count)"

    # Re-import night 1 after a different recording has been loaded.
    $message = Import-Night 1
    Check 're-importing an existing recording reports success' ($message -eq $success) "message='$message'"
    Check 're-importing an existing recording does not create a duplicate' ($log.ListRows.Count -eq 2) "rows=$($log.ListRows.Count)"
    $kept = 0
    for ($k = 0; $k -lt $manual.Count; $k++) { if ($log.DataBodyRange.Cells.Item(1, 13 + $k).Value2 -eq $manualBefore[$k]) { $kept++ } }
    Check 'all 11 manually entered fields are preserved on re-import' ($kept -eq $manual.Count) "preserved=$kept of $($manual.Count)"
    $same = 0
    foreach ($c in $measuredCols) { if ($log.DataBodyRange.Cells.Item(1, $c).Value2 -eq $before[$c]) { $same++ } }
    Check 'measured values are unchanged by the re-import' ($same -eq 15) "unchanged=$same of 15"

    Write-Host ''
    Write-Host "--- Importing nights 3 to $Nights ---"
    $rowsRight = 2; $messagesRight = 2
    for ($i = 3; $i -le $Nights; $i++) {
        $message = Import-Night $i
        if ($message -eq $success) { $messagesRight++ } else { Write-Host "      night ${i}: message='$message'" }
        if ($log.ListRows.Count -eq $i) { $rowsRight++ } else { Write-Host "      night ${i}: rows=$($log.ListRows.Count)" }
    }
    Check "every one of $Nights recordings reported success" ($messagesRight -eq $Nights) "ok=$messagesRight"
    Check "each new recording added exactly one row ($Nights rows)" ($rowsRight -eq $Nights -and $log.ListRows.Count -eq $Nights) "rows=$($log.ListRows.Count)"

    $utcBefore = Get-ColumnValues $log 1
    $message = Import-Night 3
    Check 're-importing an earlier recording (night 3) does not add a row' ($log.ListRows.Count -eq $Nights) "rows=$($log.ListRows.Count)"
    $utc = Get-ColumnValues $log 1
    $moved = 0; for ($r = 0; $r -lt $Nights; $r++) { if ($utc[$r] -ne $utcBefore[$r]) { $moved++ } }
    Check 're-importing an earlier recording leaves every row in place' ($moved -eq 0) "changed=$moved"
    $message = Import-Night 3
    Check 'pressing the button again for the recording already loaded does not add a row' ($log.ListRows.Count -eq $Nights) "rows=$($log.ListRows.Count)"
    $kept = 0
    for ($k = 0; $k -lt $manual.Count; $k++) { if ($log.DataBodyRange.Cells.Item(1, 13 + $k).Value2 -eq $manualBefore[$k]) { $kept++ } }
    Check "manual fields of night 1 still intact after $Nights imports" ($kept -eq $manual.Count) "preserved=$kept"

    Write-Host ''
    Write-Host '--- UTC identification and time-zone handling ---'
    $local = Get-ColumnValues $log 'Recording date (local)'
    $offset = Get-ColumnValues $log 'UTC offset (h)'
    $utcRight = 0; $offsetRight = 0; $localRight = 0; $increasing = 0
    for ($r = 0; $r -lt $Nights; $r++) {
        $start = $nightStart[$r + 1]
        if ([math]::Abs($utc[$r] - (Get-Serial $start)) -lt (1.0 / 86400)) { $utcRight++ }
        $expected = $offsetBefore; if ($start -ge $switchUtc) { $expected = $offsetAfter }
        if ($offset[$r] -eq $expected) { $offsetRight++ }
        if ([math]::Abs($local[$r] - ($utc[$r] + $expected / 24.0)) -lt 1e-9) { $localRight++ }
        if ($r -gt 0 -and $utc[$r] -gt $utc[$r - 1]) { $increasing++ }
    }
    Check 'column 1 holds the UTC start of every recording (within 1 s)' ($utcRight -eq $Nights) "ok=$utcRight"
    Check 'UTC identifiers are unique and in import order' ($increasing -eq $Nights - 1) "ok=$increasing"
    Check 'each night uses the offset in effect at its UTC start' ($offsetRight -eq $Nights) "ok=$offsetRight"
    Check 'local date = UTC start + offset for every night' ($localRight -eq $Nights) "ok=$localRight"
    $nBefore = @($offset | Where-Object { $_ -eq $offsetBefore }).Count
    Check 'the mid-series offset change splits the nights as expected' ($nBefore -eq 14) "nights at first offset=$nBefore"

    # Changing the table must not disturb identification.
    $tz.DataBodyRange.Cells.Item(1, 2).Value2 = 2
    $xl.Calculate()
    Save-State
    $utcAfter = Get-ColumnValues $log 1
    $localAfter = Get-ColumnValues $log 'Recording date (local)'
    $same = 0; for ($r = 0; $r -lt $Nights; $r++) { if ($utcAfter[$r] -eq $utc[$r]) { $same++ } }
    Check 'editing the time-zone table leaves UTC identifiers unchanged' ($same -eq $Nights) "ok=$same"
    Check 'editing the time-zone table moves the displayed local date' ([math]::Abs($localAfter[0] - ($utc[0] + 2 / 24.0)) -lt 1e-9)
    $message = Import-Night 5
    Check 'duplicate prevention still works after a time-zone edit' ($log.ListRows.Count -eq $Nights) "rows=$($log.ListRows.Count)"
    $tz.DataBodyRange.Cells.Item(1, 2).Value2 = $offsetBefore
    $xl.Calculate()
    Save-State

    Write-Host ''
    Write-Host '--- Rolling means ---'
    $rolling = @(
        @{ Name = '7-night mean HR'; Source = 'Mean heart rate (bpm)'; Window = 7 },
        @{ Name = '28-night mean HR'; Source = 'Mean heart rate (bpm)'; Window = 28 },
        @{ Name = '7-night mean lnRMSSD'; Source = 'lnRMSSD'; Window = 7 },
        @{ Name = '28-night mean lnRMSSD'; Source = 'lnRMSSD'; Window = 28 },
        @{ Name = '7-night screened lnRMSSD'; Source = 'Screened lnRMSSD'; Window = 7 },
        @{ Name = '28-night screened lnRMSSD'; Source = 'Screened lnRMSSD'; Window = 28 }
    )
    foreach ($spec in $rolling) {
        $source = Get-ColumnValues $log $spec.Source
        $values = Get-ColumnValues $log $spec.Name
        $w = $spec.Window
        $naRight = 0; $meanRight = 0; $worst = 0.0
        for ($r = 0; $r -lt $Nights; $r++) {
            if ($r -lt $w - 1) { if (Test-NA $values[$r]) { $naRight++ } }
            else {
                $sum = 0.0; for ($j = $r - $w + 1; $j -le $r; $j++) { $sum += [double]$source[$j] }
                $diff = 1.0; if ($values[$r] -is [double]) { $diff = [math]::Abs($values[$r] - $sum / $w) }
                if ($diff -gt $worst) { $worst = $diff }
                if ($diff -lt 1e-9) { $meanRight++ }
            }
        }
        $expectNa = $w - 1; $expectMean = $Nights - $w + 1
        Check ("{0}: #N/A for the first {1} nights, then correct for {2}" -f $spec.Name, $expectNa, $expectMean) `
            ($naRight -eq $expectNa -and $meanRight -eq $expectMean) "na=$naRight mean=$meanRight worst=$worst"
    }

    Write-Host ''
    Write-Host '--- Trend charts ---'
    $trend = $wb.Worksheets.Item('Longitudinal Trends')
    $trend.Activate()
    $expectedSeries = @{ 'LogHR' = 3; 'LogRMSSD' = 1; 'LogLnRMSSD' = 3 }
    $found = @{}
    $index = 0
    foreach ($co in @($trend.ChartObjects())) {
        $index++
        $chart = $co.Chart
        $firstFormula = [string]$chart.SeriesCollection(1).Formula
        $key = $null
        foreach ($name in $expectedSeries.Keys) { if ($firstFormula -match ("!" + $name + ",\d+\)$")) { $key = $name } }
        $count = $chart.SeriesCollection().Count
        $found[$key] = $count
        $pointsRight = 0; $zeros = 0; $kinds = @{}
        for ($s = 1; $s -le $count; $s++) {
            $series = $chart.SeriesCollection($s)
            $vals = @($series.Values)
            if ($vals.Count -eq $Nights) { $pointsRight++ }
            $isRolling = ([string]$series.Formula -match '(7|28),\d+\)$')
            if ($isRolling) {
                $w = 7; if ([string]$series.Formula -match '28,\d+\)$') { $w = 28 }
                for ($r = 0; $r -lt $w - 1; $r++) {
                    $v = $vals[$r]
                    $kind = 'null'; if ($null -ne $v) { $kind = $v.GetType().Name }
                    $kinds[$kind] = 1
                    if (($v -is [double] -or $v -is [int]) -and $v -eq 0) { $zeros++ }
                }
            }
        }
        $title = ''; if ($chart.HasTitle) { $title = [string]$chart.ChartTitle.Text }
        $nightly = @($chart.SeriesCollection(1).Values)
        $lowest = ($nightly | Measure-Object -Minimum).Minimum
        $highest = ($nightly | Measure-Object -Maximum).Maximum
        $scale = $chart.Axes(2)
        $visible = ($lowest -ge $scale.MinimumScale -and $highest -le $scale.MaximumScale)
        $axisTitle = ''; try { $axis = $chart.Axes(2); if ($axis.HasTitle) { $axisTitle = [string]$axis.AxisTitle.Text } } catch { }
        Check "chart '$title': $count series, each with $Nights points" ($pointsRight -eq $count) "series with $Nights points=$pointsRight"
        Check "chart '$title': every nightly value lies within the value axis" $visible "data $lowest..$highest, axis $($scale.MinimumScale)..$($scale.MaximumScale)"
        Check "chart '$title': unavailable rolling means are not plotted as zero" ($zeros -eq 0) "zeros=$zeros kinds=$($kinds.Keys -join ',')"
        Check "chart '$title': labels spell lnRMSSD with a lowercase l" (-not (($title + ' ' + $axisTitle) -cmatch 'InRMSSD')) "title='$title' axis='$axisTitle'"
        try {
            $png = Join-Path $chartDir ("trend-{0}.png" -f $index)
            if ($chart.Export($png)) { Write-Host "      exported $png" }
        } catch { Write-Host "      (chart image export not available: $($_.Exception.Message))" }
    }
    Check 'mean heart-rate chart keeps nightly, 7-night and 28-night series' ($found['LogHR'] -eq 3) "series=$($found['LogHR'])"
    Check 'screened RMSSD chart shows RMSSD only (no lnRMSSD rolling means)' ($found['LogRMSSD'] -eq 1) "series=$($found['LogRMSSD'])"
    Check 'screened lnRMSSD chart keeps nightly, 7-night and 28-night series' ($found['LogLnRMSSD'] -eq 3) "series=$($found['LogLnRMSSD'])"
    $short = @()
    foreach ($name in 'LogDate', 'LogHR', 'LogHR7', 'LogHR28', 'LogRMSSD', 'LogLnRMSSD', 'LogLnRMSSD7', 'LogLnRMSSD28') {
        $rows = $wb.Names.Item($name).RefersToRange.Rows.Count
        if ($rows -ne $Nights) { $short += "$name=$rows" }
    }
    Check "all eight log named ranges cover $Nights nights" ($short.Count -eq 0) ($short -join ', ')
    Check 'chart date axis uses the local recording date' ([string]$wb.Names.Item('LogDate').RefersTo -match 'Recording date \(local\)')

    Write-Host ''
    Write-Host '--- Dashboard (last imported recording) ---'
    $windows = [int]$xl.WorksheetFunction.Count($wb.Worksheets.Item('Overnight Analysis').Range('A2:A145'))
    $timeRows = $wb.Names.Item('NightTime').RefersToRange.Rows.Count
    Check "5-minute windows found for a 1-hour recording ($windows)" ($windows -ge 11 -and $windows -le 12)
    Check 'dashboard chart range matches the number of windows' ($timeRows -eq $windows) "rows=$timeRows"
    $dash = $wb.Worksheets.Item('Dashboard')
    $dashDate = $dash.Range('B2').Value2
    $summaryLocal = $wb.Worksheets.Item('HRV Analysis').Range('P2').Value2
    Check 'dashboard shows the local recording date' ($dashDate -eq $summaryLocal)

    Write-Host ''
    Write-Host '--- Sample of the synthetic log (not physiological data) ---'
    $hr = Get-ColumnValues $log 'Mean heart rate (bpm)'
    $hr7 = Get-ColumnValues $log '7-night mean HR'
    $hr28 = Get-ColumnValues $log '28-night mean HR'
    $ln7 = Get-ColumnValues $log '7-night screened lnRMSSD'
    function Show($v) { if (Test-NA $v) { return '#N/A' } elseif ($v -is [double]) { return ('{0:F3}' -f $v) } else { return [string]$v } }
    Write-Host ('{0,5}  {1,-17} {2,-17} {3,6} {4,9} {5,9} {6,9} {7,11}' -f 'night', 'start (UTC)', 'date (local)', 'offset', 'mean HR', '7-n HR', '28-n HR', '7-n lnRMSSD')
    foreach ($r in @(0, 5, 6, 13, 14, 26, 27, ($Nights - 1))) {
        Write-Host ('{0,5}  {1,-17} {2,-17} {3,6} {4,9} {5,9} {6,9} {7,11}' -f ($r + 1),
            [datetime]::FromOADate($utc[$r]).ToString('yyyy-MM-dd HH:mm'), [datetime]::FromOADate($local[$r]).ToString('yyyy-MM-dd HH:mm'),
            $offset[$r], (Show $hr[$r]), (Show $hr7[$r]), (Show $hr28[$r]), (Show $ln7[$r]))
    }
}
finally {
    Stop-TestExcel
}

Write-Host ''
Check 'the template in the repository was not modified by the test' ((Get-FileHash -LiteralPath $Template -Algorithm SHA256).Hash -eq $templateHash)

if ($KeepWork) { Write-Host "Scratch files kept in: $WorkDir" }
else { Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
if ($script:excelFailures -gt 0) {
    Write-Host "KNOWN ISSUE: the refresh failed in $script:excelFailures of $script:macroRuns macro runs (Excel crashed or the macro reported 'Refresh failed'); each was retried from the last saved state."
} else {
    Write-Host "Excel stability: no refresh failures in $script:macroRuns macro runs."
}
Write-Host "$script:passed passed, $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
