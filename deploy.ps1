<#
.SYNOPSIS
    Copies the UE4SS mod (src\<folder>) into the game's ue4ss\Mods\<folder>.

.DESCRIPTION
    Reads mod.json. The target is <game folder>\<win64Path>\ue4ss\Mods\<folder>; the game folder is
    $env:UE5_GAMES_DIR\<gameFolder> unless -GameDir or -ModsDir is given. UE4SS must be installed in the game.

    The script mirrors src\<folder> into the target: files that are no longer in src are removed there, and nothing
    else in ue4ss\Mods is touched. The mod folder holds enabled.txt, so UE4SS starts the mod without an entry in
    mods.txt. UE4SS loads Lua mods when the game starts, so a change shows after the next game start (unless hot
    reload is on in UE4SS-settings.ini).

    Exit codes: 0 = deployed or already up to date, 1 = error.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\deploy.ps1
#>
param(
    # The game's install folder. Default: $env:UE5_GAMES_DIR\<gameFolder of mod.json>.
    [string]$GameDir,
    # The UE4SS Mods folder. Default: <GameDir>\<win64Path of mod.json>\ue4ss\Mods.
    [string]$ModsDir
)

$ErrorActionPreference = "Stop"

$mod = Get-Content (Join-Path $PSScriptRoot "mod.json") -Raw | ConvertFrom-Json
$source = Join-Path $PSScriptRoot "src\$($mod.folder)"
if (-not (Test-Path (Join-Path $source "Scripts\main.lua"))) {
    throw "$source\Scripts\main.lua not found."
}
if (-not $ModsDir) {
    if (-not $GameDir) {
        if (-not $env:UE5_GAMES_DIR) {
            throw "The game folder is unknown: set UE5_GAMES_DIR (the folder that holds '$($mod.gameFolder)'), or use -GameDir or -ModsDir."
        }
        $GameDir = Join-Path $env:UE5_GAMES_DIR $mod.gameFolder
    }
    $ue4ss = Join-Path (Join-Path $GameDir $mod.win64Path) "ue4ss"
    if (-not (Test-Path (Join-Path $ue4ss "UE4SS.dll"))) {
        throw "UE4SS is not installed in the game ($ue4ss\UE4SS.dll is missing). Install UE4SS first."
    }
    $ModsDir = Join-Path $ue4ss "Mods"
}
$target = Join-Path $ModsDir $mod.folder

robocopy $source $target /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
$code = $LASTEXITCODE
if ($code -ge 8) {
    throw "robocopy failed with exit code $code"
}
if ($code -eq 0) {
    Write-Host "Already up to date: $target" -ForegroundColor Green
} else {
    Write-Host "Deployed $($mod.name) $($mod.version) to $target (active from the next game start)" -ForegroundColor Green
}
exit 0
