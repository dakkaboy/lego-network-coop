param([string]$OutputDirectory = 'build', [switch]$SteeringTraceOnly, [switch]$WithIntentObserver, [switch]$WithPoseObserver, [switch]$WithBaseAimObserver, [switch]$WithConstructorReturnObserver, [switch]$WithActionTransitionObserver, [switch]$WithConstructorQueryObserver, [switch]$WithHitEntryObserver)
$ErrorActionPreference = 'Stop'
if ($SteeringTraceOnly -or $WithIntentObserver -or $WithPoseObserver -or $WithBaseAimObserver -or $WithConstructorReturnObserver -or $WithActionTransitionObserver -or $WithConstructorQueryObserver) {
    throw 'Diagnostic observer builds require a separate reviewed configuration.'
}
$cameraBuildDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $OutputDirectory))
$hitEntryObserver = if ($WithHitEntryObserver) { 'ON' } else { 'OFF' }
cmake --preset windows-x86 -S $PSScriptRoot -B $cameraBuildDirectory "-DCLONEWARS_HIT_ENTRY_OBSERVER=$hitEntryObserver"
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed' }
cmake --build $cameraBuildDirectory
if ($LASTEXITCODE -ne 0) { throw 'DLL build failed' }
