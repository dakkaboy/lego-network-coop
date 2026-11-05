param([string]$OutputDirectory = 'build', [switch]$SteeringTraceOnly, [switch]$WithIntentObserver, [switch]$WithPoseObserver, [switch]$WithBaseAimObserver, [switch]$WithConstructorReturnObserver, [switch]$WithActionTransitionObserver, [switch]$WithConstructorQueryObserver, [switch]$WithHitEntryObserver)
$ErrorActionPreference = 'Stop'
if ($SteeringTraceOnly -or $WithIntentObserver -or $WithPoseObserver -or $WithBaseAimObserver -or $WithConstructorReturnObserver -or $WithActionTransitionObserver -or $WithConstructorQueryObserver) {
    throw 'Diagnostic observer builds require a separate reviewed configuration.'
}
$cameraBuildDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $OutputDirectory))
$cameraBuildArgs = @('--source', (Join-Path $PSScriptRoot 'src'), '--output', $cameraBuildDirectory)
if ($WithHitEntryObserver) { $cameraBuildArgs += '--with-hit-entry-observer' }
python (Join-Path $PSScriptRoot 'tools\build_coherent_dll.py') @cameraBuildArgs
if ($LASTEXITCODE -ne 0) { throw 'Coherent DLL build failed' }
