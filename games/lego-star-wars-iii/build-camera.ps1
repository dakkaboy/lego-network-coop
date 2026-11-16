param([string]$OutputDirectory = 'build', [switch]$WithConstructorQueryObserver, [switch]$WithHitEntryObserver, [switch]$WithTracy, [string]$ZigExecutable = 'zig')
$ErrorActionPreference = 'Stop'
$cameraBuildDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $OutputDirectory))
$hitEntryObserver = if ($WithHitEntryObserver) { 'true' } else { 'false' }
$constructorQueryObserver = if ($WithConstructorQueryObserver) { 'true' } else { 'false' }
$tracy = if ($WithTracy) { 'true' } else { 'false' }
$zigExecutable = (Get-Command $ZigExecutable -ErrorAction Stop).Source
if ((& $zigExecutable version) -ne '0.17.1') { throw 'Zig 0.17.1 is required.' }
Push-Location $PSScriptRoot
try {
    & $zigExecutable build dll --prefix $cameraBuildDirectory --prefix-exe-dir . "-Dhit-entry=$hitEntryObserver" "-Dconstructor-query=$constructorQueryObserver" "-Dtracy=$tracy"
    if ($LASTEXITCODE -ne 0) { throw 'DLL build failed' }
} finally {
    Pop-Location
}
