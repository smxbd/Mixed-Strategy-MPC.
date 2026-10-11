param([string]$Entry='run_phase_b')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$run=Join-Path $root ('results\job_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $run | Out-Null
if ($Entry -notmatch '^[a-zA-Z][a-zA-Z0-9_]*$') { throw 'Entry must be a MATLAB function name.' }
$batch="addpath('"+$root.Replace("'","''")+"'); startup_ml_ems; "+$Entry
$p=Start-Process -FilePath 'D:\Matlab\Matlab R2024b\bin\matlab.exe' -ArgumentList @('-wait','-nosplash','-batch',('"'+$batch+'"'),'-logfile',('"'+(Join-Path $run 'matlab.log')+'"')) -WorkingDirectory $run -WindowStyle Hidden -PassThru
@{pid=$p.Id;entry=$Entry;run=$run} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'results\latest_job.json') -Encoding utf8
Get-Content -LiteralPath (Join-Path $root 'results\latest_job.json')
