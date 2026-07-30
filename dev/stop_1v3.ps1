$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pidFile = Join-Path $projectRoot 'tmp\network-instance-pids.txt'

if (-not (Test-Path -LiteralPath $pidFile)) {
    Write-Host 'No multiplayer instance PID file was found.'
    exit 0
}

$recordedProcessIds = @()
foreach ($line in Get-Content -LiteralPath $pidFile) {
    $processId = 0
    if (-not [int]::TryParse($line.Trim(), [ref]$processId)) {
        continue
    }
    $recordedProcessIds += $processId
}

$targetProcessIds = [System.Collections.Generic.HashSet[int]]::new()
foreach ($processId in $recordedProcessIds) {
    [void]$targetProcessIds.Add($processId)
}

# The console build can spawn a second Godot process on Windows. Resolve only
# descendants of this launch's recorded PIDs before stopping anything.
$processTable = @(Get-CimInstance Win32_Process)
$foundDescendant = $true
while ($foundDescendant) {
    $foundDescendant = $false
    foreach ($processEntry in $processTable) {
        if (
            $processEntry.Name -notlike 'Godot*' -or
            -not $targetProcessIds.Contains([int]$processEntry.ParentProcessId) -or
            $targetProcessIds.Contains([int]$processEntry.ProcessId)
        ) {
            continue
        }
        [void]$targetProcessIds.Add([int]$processEntry.ProcessId)
        $foundDescendant = $true
    }
}

foreach ($processId in $targetProcessIds) {
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($process -and $process.ProcessName -like 'Godot*') {
        Stop-Process -Id $processId -Force
        Write-Host "Stopped Godot process $processId."
    }
}

Remove-Item -LiteralPath $pidFile -Force
