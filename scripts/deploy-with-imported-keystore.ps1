param(
  [Parameter(Mandatory = $true)]
  [string]$Account,

  [Parameter(Mandatory = $true)]
  [string]$ExpectedAddress
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$localCast = Join-Path $projectRoot ".tools\foundry\cast.exe"
if (Test-Path -LiteralPath $localCast) {
  $cast = $localCast
} else {
  $pathCast = Get-Command cast -ErrorAction SilentlyContinue
  if (-not $pathCast) {
    throw "Foundry cast was not found."
  }
  $cast = $pathCast.Source
}

Write-Host "Unlock the keystore once to verify its public address." -ForegroundColor Cyan
$actualAddress = (& $cast wallet address --account $Account).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not unlock $Account."
}
if ($actualAddress.ToLowerInvariant() -ne $ExpectedAddress.ToLowerInvariant()) {
  throw "Signer mismatch: expected $ExpectedAddress, received $actualAddress."
}

Write-Host "Signer verified: $actualAddress" -ForegroundColor Green
Write-Host "Unlock the keystore again to broadcast the deployment." -ForegroundColor Cyan

$env:ARC_RPC_URL = "https://rpc.blockdaemon.testnet.arc.io"
$env:FEE_RECIPIENT = $ExpectedAddress
$env:PROTOCOL_FEE_BPS = "0"

& (Join-Path $PSScriptRoot "deploy-arc-testnet.ps1") -Account $Account
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
