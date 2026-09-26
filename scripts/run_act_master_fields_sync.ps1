[CmdletBinding()]
param(
  [string]$ProjectRef = 'crwvenlejfkrouimnxui',
  [int]$MaximumResumeCalls = 160,
  [int]$ResumeDelaySeconds = 5
)

$ErrorActionPreference = 'Stop'

function Get-BangkokNow {
  try {
    $zone = [TimeZoneInfo]::FindSystemTimeZoneById('SE Asia Standard Time')
  }
  catch {
    $zone = [TimeZoneInfo]::FindSystemTimeZoneById('Asia/Bangkok')
  }
  return [TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow, $zone)
}

function Invoke-SyncFunction {
  param(
    [Parameter(Mandatory)] [hashtable]$Headers,
    [Parameter(Mandatory)] [hashtable]$Payload,
    [Parameter(Mandatory)] [string]$FunctionUrl
  )

  try {
    return Invoke-RestMethod `
      -Method Post `
      -Uri $FunctionUrl `
      -Headers $Headers `
      -Body ($Payload | ConvertTo-Json -Depth 8) `
      -TimeoutSec 240
  }
  catch {
    $details = $_.ErrorDetails.Message
    if ($details) {
      try {
        return $details | ConvertFrom-Json
      }
      catch {
        throw "ACT sync request failed: $details"
      }
    }
    throw
  }
}

$bangkokNow = Get-BangkokNow
$sourceTo = $bangkokNow.ToString('yyyy-MM-dd')
$sourceFrom = "{0}-01-01" -f $bangkokNow.Year
$functionUrl = "https://$ProjectRef.supabase.co/functions/v1/act-master-fields-sync"
$restUrl = "https://$ProjectRef.supabase.co/rest/v1"

$rawKeys = supabase projects api-keys --project-ref $ProjectRef --output json
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to read Supabase project API keys.'
}
$keys = $rawKeys | ConvertFrom-Json
$serviceKey = ($keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
if (-not $serviceKey) {
  throw 'Supabase service_role key was not found.'
}

$headers = @{
  Authorization  = "Bearer $serviceKey"
  apikey         = $serviceKey
  'Content-Type' = 'application/json'
}

$encodedDate = [Uri]::EscapeDataString($sourceTo)
$existingUrl = "$restUrl/act_sync_runs?dry_run=eq.false&source_to=eq.$encodedDate&select=id,status,summary,error_message,completed_at&order=started_at.desc&limit=1"
$existing = @(Invoke-RestMethod -Uri $existingUrl -Headers $headers -TimeoutSec 60)

$runId = $null
if ($existing.Count -gt 0) {
  $latest = $existing[0]
  $runId = [string]$latest.id
  if ($latest.status -eq 'COMPLETED') {
    [ordered]@{
      run_id       = $runId
      status       = 'COMPLETED'
      source_to    = $sourceTo
      duplicate_run_skipped = $true
      summary      = $latest.summary
      completed_at = $latest.completed_at
    } | ConvertTo-Json -Depth 20
    exit 0
  }
  if ($latest.status -in @('FAILED', 'BLOCKED', 'READY')) {
    [ordered]@{
      run_id        = $runId
      status        = [string]$latest.status
      source_to     = $sourceTo
      error_message = $latest.error_message
      summary       = $latest.summary
    } | ConvertTo-Json -Depth 20
    exit 2
  }
}

if ($runId) {
  $response = Invoke-SyncFunction -Headers $headers -FunctionUrl $functionUrl -Payload @{ runId = $runId }
}
else {
  $response = Invoke-SyncFunction -Headers $headers -FunctionUrl $functionUrl -Payload @{
    from           = $sourceFrom
    to             = $sourceTo
    apply          = $true
    sources        = @('FC', 'PS', 'SC')
    exportMode     = 'table'
    includeWkt     = $true
    minimumRows    = 30000
    maxChangeRatio = 0.25
  }
  $runId = [string]$response.run_id
}

if (-not $runId) {
  throw 'ACT sync did not return a run id.'
}

for ($attempt = 1; $attempt -le $MaximumResumeCalls; $attempt++) {
  $status = [string]$response.status
  if ($status -in @('COMPLETED', 'FAILED', 'BLOCKED', 'READY')) {
    break
  }
  if ($response.error) {
    throw "ACT sync failed before reaching a terminal status: $($response.error)"
  }
  if (-not $status) {
    throw 'ACT sync returned neither status nor a recognized terminal response.'
  }
  if ($ResumeDelaySeconds -gt 0) {
    Start-Sleep -Seconds $ResumeDelaySeconds
  }
  $response = Invoke-SyncFunction -Headers $headers -FunctionUrl $functionUrl -Payload @{ runId = $runId }
}

$runUrl = "$restUrl/act_sync_runs?id=eq.$runId&select=id,status,source_from,source_to,source_counts,summary,error_message,started_at,completed_at"
$run = @(Invoke-RestMethod -Uri $runUrl -Headers $headers -TimeoutSec 60)
if ($run.Count -eq 0) {
  throw "ACT sync run disappeared: $runId"
}

$final = $run[0]
$report = [ordered]@{
  run_id        = [string]$final.id
  status        = [string]$final.status
  source_from   = $final.source_from
  source_to     = $final.source_to
  source_counts = $final.source_counts
  summary       = $final.summary
  error_message = $final.error_message
  started_at    = $final.started_at
  completed_at  = $final.completed_at
}
$report | ConvertTo-Json -Depth 20

if ($final.status -ne 'COMPLETED') {
  exit 2
}
