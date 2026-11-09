param(
    [Parameter(Mandatory = $true)]
    [string] $SqlFile,

    [string] $ProjectId = $env:EV_PROJECT_ID,
    [string] $Location = $(if ($env:EV_BQ_LOCATION) { $env:EV_BQ_LOCATION } else { "us-central1" }),
    [string] $MaximumBytesBilled = "500GB"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $SqlFile -PathType Leaf)) {
    throw "SQL file not found: $SqlFile"
}

$bq = Get-Command bq.cmd -ErrorAction SilentlyContinue
if (-not $bq) {
    $sdkBq = Join-Path ${env:LOCALAPPDATA} "Google\Cloud SDK\google-cloud-sdk\bin\bq.cmd"
    if (-not (Test-Path -LiteralPath $sdkBq -PathType Leaf)) {
        throw "bq.cmd was not found. Install Google Cloud CLI or add it to PATH."
    }
    $bqPath = $sdkBq
} else {
    $bqPath = $bq.Source
}

$arguments = @(
    "query",
    "--use_legacy_sql=false",
    "--location=$Location",
    "--maximum_bytes_billed=$MaximumBytesBilled"
)
if ($ProjectId) {
    $arguments += "--project_id=$ProjectId"
}

$sql = Get-Content -LiteralPath $SqlFile -Raw
$sql | & $bqPath @arguments
if ($LASTEXITCODE -ne 0) {
    throw "BigQuery query failed for $SqlFile with exit code $LASTEXITCODE."
}
