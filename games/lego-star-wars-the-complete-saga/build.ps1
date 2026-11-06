[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'build'),
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
$output = New-Item -ItemType Directory -Force -Path $OutputDirectory
$flags = @('-target', 'x86-windows-gnu', '-std=c++23', '-O2', '-Wall', '-Wextra', '-Werror')
$proxy = Join-Path $output.FullName 'd3d9.dll'

& zig c++ @flags -shared "$PSScriptRoot/src/d3d9_proxy.cpp" "$PSScriptRoot/src/d3d9_proxy.def" -o $proxy
if ($LASTEXITCODE -ne 0) { throw 'Could not build d3d9.dll.' }

if ($Test) {
    $smoke = Join-Path $output.FullName 'd3d9_smoke.exe'
    & zig c++ @flags -municode "$PSScriptRoot/tests/d3d9_smoke.cpp" -o $smoke
    if ($LASTEXITCODE -ne 0) { throw 'Could not build the Direct3D smoke test.' }
    & $smoke $proxy
    if ($LASTEXITCODE -ne 0) { throw "Direct3D smoke test failed with exit code $LASTEXITCODE." }
}
