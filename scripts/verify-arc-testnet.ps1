param(
  [Parameter(Mandatory = $true)]
  [string]$Address,
  [Parameter(Mandatory = $true)]
  [string]$Contract,
  [string]$ConstructorArgs = ""
)

$ErrorActionPreference = "Stop"
$forge = Join-Path $PSScriptRoot "forge.ps1"
$args = @(
  "verify-contract", $Address, $Contract,
  "--chain-id", "5042002",
  "--verifier", "blockscout",
  "--verifier-url", "https://testnet.arcscan.app/api/"
)
if ($ConstructorArgs) { $args += @("--constructor-args", $ConstructorArgs) }
& $forge @args
exit $LASTEXITCODE
