param([string]$MatlabExe = 'D:\Matlab\Matlab R2024b\bin\matlab.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$runtimeRoot = Join-Path $PSScriptRoot 'runtime'
$runDir = Join-Path $runtimeRoot ('probe_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8))
if (!(Test-Path -LiteralPath $MatlabExe)) { throw "MATLAB executable not found: $MatlabExe" }
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
foreach ($name in @('EMT.mdl','parameter.m')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $runDir
}
Get-ChildItem -LiteralPath $projectRoot -File -Filter '*.jpg' | Copy-Item -Destination $runDir
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe_original_model.m') -Destination $runDir
@{project_root=$projectRoot;purpose='isolated stage A audit'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDir 'isolation_manifest.json') -Encoding utf8
$before = foreach ($name in @('EMT.mdl','parameter.m','parameter.mat','result.mat')) {
    [pscustomobject]@{name=$name;sha256=(Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash}
}
$before | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDir 'source_hashes_before.json') -Encoding utf8
$batch = "probe_original_model('" + $runDir.Replace("'", "''") + "')"
$process = Start-Process -FilePath $MatlabExe -ArgumentList @('-wait','-nosplash','-batch',('"'+$batch+'"'),'-logfile',('"'+(Join-Path $runDir 'matlab_batch.log')+'"')) -WorkingDirectory $runDir -WindowStyle Hidden -PassThru -Wait
foreach ($item in $before) {
    if ((Get-FileHash -LiteralPath (Join-Path $projectRoot $item.name)).Hash -ne $item.sha256) { throw "Original changed: $($item.name)" }
}
Write-Output "Audit output: $runDir"
if ($process.ExitCode -ne 0) { throw "MATLAB exit code: $($process.ExitCode). Inspect matlab_batch.log." }
$audit = Get-Content -LiteralPath (Join-Path $runDir 'runtime_audit.json') -Raw | ConvertFrom-Json
if ($audit.load_status -ne 'passed' -or $audit.compile_status -ne 'passed') { throw 'Model load or compilation failed; inspect runtime_audit.json.' }
Write-Output 'Model loaded and compiled; no trajectory simulation was requested.'
