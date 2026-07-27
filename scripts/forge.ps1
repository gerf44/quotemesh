param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $ForgeArguments
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$localForge = Join-Path $projectRoot ".tools\foundry\forge.exe"

if (Test-Path -LiteralPath $localForge) {
  & $localForge @ForgeArguments
  exit $LASTEXITCODE
}

$pathForge = Get-Command forge -ErrorAction SilentlyContinue
if (-not $pathForge) {
  throw "Foundry forge was not found. Install Foundry or provide .tools\foundry\forge.exe."
}

& $pathForge.Source @ForgeArguments
exit $LASTEXITCODE
