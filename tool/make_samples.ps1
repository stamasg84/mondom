# Generates voices/samples/<voice-id>.wav for every voice in voices/catalog.json.
# Needs the official python.org Python 3.12 (`winget install Python.Python.3.12`):
# sherpa-onnx 1.x has no wheels for newer Pythons, and Smart App Control blocks
# unsigned builds such as uv's managed Python, so we use the signed installer.
# Sets up tool/.venv (sherpa-onnx pinned to the app's 1.x version).
# With -Clean, removes tool/.venv and tool/.cache afterwards (Python 3.12 stays;
# uninstall it with `winget uninstall Python.Python.3.12` if you like).
param([switch]$Force, [switch]$Clean)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$venv = Join-Path $PSScriptRoot '.venv'
$py = Join-Path $venv 'Scripts/python.exe'
$sherpaVersion = '1.13.8'   # same as pubspec.yaml (2.x dropped espeak-ng)

if (-not (Test-Path $py)) {
    py -3.12 --version
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.12 not found: winget install Python.Python.3.12' }
    py -3.12 -m venv $venv
    & $py -m pip install --quiet "sherpa-onnx==$sherpaVersion" numpy
    if ($LASTEXITCODE -ne 0) { throw 'pip install failed' }
}
$args2 = @($root)
if ($Force) { $args2 += '--force' }
& $py (Join-Path $PSScriptRoot 'make_samples.py') @args2
if ($LASTEXITCODE -ne 0) { throw 'make_samples.py failed' }

if ($Clean) {
    Remove-Item -Recurse -Force $venv, (Join-Path $PSScriptRoot '.cache') -ErrorAction SilentlyContinue
    Write-Host 'Cleaned tool/.venv and tool/.cache.'
}
