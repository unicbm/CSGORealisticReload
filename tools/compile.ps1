param(
    [string]$SourceModScriptingDir = $env:SM_SCRIPTING_DIR
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot "addons\sourcemod\scripting\realistic_reload.sp"
$outputDir = Join-Path $repoRoot "addons\sourcemod\plugins"
$output = Join-Path $outputDir "realistic_reload.smx"

if ([string]::IsNullOrWhiteSpace($SourceModScriptingDir)) {
    throw "Pass -SourceModScriptingDir or set SM_SCRIPTING_DIR to your SourceMod scripting directory."
}

$compiler = Join-Path $SourceModScriptingDir "spcomp.exe"
$includeDir = Join-Path $SourceModScriptingDir "include"

if (-not (Test-Path -LiteralPath $compiler)) {
    throw "Missing compiler: $compiler"
}

if (-not (Test-Path -LiteralPath $includeDir)) {
    throw "Missing include directory: $includeDir"
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

& $compiler $source "-i$includeDir" "--output=$output"
if ($LASTEXITCODE -ne 0) {
    throw "spcomp failed with exit code $LASTEXITCODE"
}

Get-Item -LiteralPath $output | Select-Object FullName, Length, LastWriteTime
