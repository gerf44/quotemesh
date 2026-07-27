param(
  [Parameter(Mandatory = $true)]
  [string]$Account
)

$ErrorActionPreference = "Stop"
$forge = Join-Path $PSScriptRoot "forge.ps1"

& $forge script script/Deploy.s.sol:Deploy `
  --rpc-url $env:ARC_RPC_URL `
  --account $Account `
  --broadcast `
  -vvvv

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
