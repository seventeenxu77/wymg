param(
    [int]$Port = 7777,
    [switch]$AutoMove,
    [switch]$SkipHide,
    [switch]$CombatTest,
    [switch]$ToolTest
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDirectory = Join-Path $projectRoot 'logs'
$runtimeDirectory = Join-Path $projectRoot 'tmp'
$pidFile = Join-Path $runtimeDirectory 'network-instance-pids.txt'

New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null

function Resolve-GodotExecutable {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command -and $command.Source.EndsWith('.exe')) {
        return $command.Source
    }

    $wrapperPath = if ($command) {
        $command.Source
    } else {
        Join-Path $env:USERPROFILE 'bin\godot.cmd'
    }
    if (Test-Path -LiteralPath $wrapperPath) {
        $executableLine = Get-Content -LiteralPath $wrapperPath |
            Where-Object { $_ -match '^"[^"]+\.exe"' } |
            Select-Object -First 1
        if ($executableLine -and $executableLine -match '^"([^"]+\.exe)"') {
            return $Matches[1]
        }
    }

    throw 'Godot executable was not found in PATH or %USERPROFILE%\bin\godot.cmd.'
}

$godotExecutable = Resolve-GodotExecutable
$processes = @()

$serverArguments = @(
    '--headless',
    '--path', $projectRoot,
    '--log-file', 'logs/dev-server.log',
    '--',
    '--server',
    "--port=$Port",
    '--instance=server',
    '--name=DedicatedServer',
    '--auto-start'
)
if ($AutoMove -or $SkipHide -or $CombatTest -or $ToolTest) {
    $serverArguments += '--debug-skip-hide'
}
if ($CombatTest) {
    $serverArguments += '--debug-combat-test'
}
if ($ToolTest) {
    $serverArguments += '--debug-tool-test'
}
$server = Start-Process -FilePath $godotExecutable -ArgumentList $serverArguments -WindowStyle Hidden -PassThru
$processes += $server
Start-Sleep -Milliseconds 900

$clients = @(
    @{ Instance = 'monster'; Slot = 'monster'; X = 0; Y = 0; Name = 'Monster'; Direction = 'right' },
    @{ Instance = 'thief-1'; Slot = 'thief-1'; X = 810; Y = 0; Name = 'Thief1'; Direction = 'down' },
    @{ Instance = 'thief-2'; Slot = 'thief-2'; X = 0; Y = 480; Name = 'Thief2'; Direction = 'up' },
    @{ Instance = 'thief-3'; Slot = 'thief-3'; X = 810; Y = 480; Name = 'Thief3'; Direction = 'left' }
)

foreach ($client in $clients) {
    $arguments = @(
        '--path', $projectRoot,
        '--resolution', '800x450',
        '--position', "$($client.X),$($client.Y)",
        '--log-file', "logs/dev-$($client.Instance).log",
        '--',
        '--client',
        '--host=127.0.0.1',
        "--port=$Port",
        "--instance=$($client.Instance)",
        "--slot=$($client.Slot)",
        "--name=$($client.Name)",
        '--auto-ready'
    )
    if ($AutoMove) {
        $arguments += "--debug-input=$($client.Direction)"
    }
    $process = Start-Process -FilePath $godotExecutable -ArgumentList $arguments -PassThru
    $processes += $process
}

$processes.Id | Set-Content -LiteralPath $pidFile -Encoding utf8

Write-Host "Started one dedicated server and four clients on UDP port $Port."
if ($CombatTest) {
    Write-Host "Combat test formation enabled: Space attacks; thieves hold F near a downed teammate to revive."
}
if ($ToolTest) {
    Write-Host "Tool test enabled: Z/X selects a tool; C uses or deploys it; trapped players alternate A/D."
}
Write-Host "Logs: $logDirectory"
Write-Host "Stop all instances with: .\dev\stop_1v3.ps1"
