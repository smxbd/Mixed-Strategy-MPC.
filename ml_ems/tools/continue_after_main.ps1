param([Parameter(Mandatory=$true)][int]$MainLauncherPid)
$ErrorActionPreference='Stop'
$mainProcess = Get-Process -Id $MainLauncherPid -ErrorAction SilentlyContinue
if ($null -ne $mainProcess) {
    if ($mainProcess.ProcessName -ne 'MATLAB') { throw 'Main process identity does not match MATLAB.' }
    Wait-Process -Id $MainLauncherPid -ErrorAction SilentlyContinue
}
# The -wait MATLAB launcher ends after its worker; inspect the catalog in the next entry.
& (Join-Path $PSScriptRoot 'launch_matlab.ps1') -Entry complete_residual_suite
