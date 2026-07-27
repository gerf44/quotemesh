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
  if (-not $pathCast) { throw "Foundry cast was not found." }
  $cast = $pathCast.Source
}

$rpc = "https://rpc.blockdaemon.testnet.arc.io"
$chainId = "5042002"
$usdc = "0x3600000000000000000000000000000000000000"
$eurc = "0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a"
$providers = "0x2Ea027838Acf30B1be649cb0738e982ad5709859"
$vault = "0xfeAe059ECd0248C917A80a079F67fDe53B7a3fe5"
$market = "0xe9633B9D35a786A5cE2ebCF3e28D5f78dDDbA3c9"
$settlements = "0x14D7Ac9BD50f66D93c21c82BB61F9bE7f72C51be"
$depositAmount = [uint64]2000000
$tradeAmount = [uint64]1000000

$outputDirectory = Join-Path $projectRoot "output"
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$transcriptPath = Join-Path $outputDirectory "lifecycle-live.log"
$resultPath = Join-Path $outputDirectory "lifecycle-result.json"
$transactions = [System.Collections.Generic.List[object]]::new()
$securePassword = $null
$passwordPointer = [IntPtr]::Zero
$plainPassword = $null

function Invoke-CastCall {
  param(
    [string]$To,
    [string]$Signature,
    [string[]]$Arguments = @()
  )

  $castArguments = @("call", $To, $Signature) + $Arguments + @("--rpc-url", $rpc)
  $value = & $cast @castArguments
  if ($LASTEXITCODE -ne 0) { throw "Read call failed: $Signature" }
  return ($value | Out-String).Trim()
}

function Invoke-CastSend {
  param(
    [string]$Label,
    [string]$To,
    [string]$Signature,
    [string[]]$Arguments = @()
  )

  Write-Host "Broadcasting $Label..." -ForegroundColor Cyan
  $castArguments =
    @("send", $To, $Signature) + $Arguments +
    @("--rpc-url", $rpc, "--account", $Account, "--json")
  $rawReceipt = $plainPassword | & $cast @castArguments
  if ($LASTEXITCODE -ne 0) { throw "$Label failed before a successful receipt." }

  $receiptText = ($rawReceipt | Out-String).Trim()
  $receipt = $receiptText | ConvertFrom-Json
  if ($receipt.status -ne "0x1") {
    throw "$Label reverted in transaction $($receipt.transactionHash)."
  }

  $transactions.Add([pscustomobject]@{
    label = $Label
    transactionHash = $receipt.transactionHash
    blockNumber = if ($receipt.blockNumber -like "0x*") {
      [Convert]::ToUInt64(($receipt.blockNumber -replace "^0x", ""), 16)
    } else {
      [uint64]$receipt.blockNumber
    }
    status = "success"
  })
  Write-Host "$Label confirmed: $($receipt.transactionHash)" -ForegroundColor Green
  return $receipt
}

Start-Transcript -Path $transcriptPath -Force | Out-Null
try {
  $actualChainId = (& $cast chain-id --rpc-url $rpc | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $actualChainId -ne $chainId) {
    throw "Unexpected chain ID: $actualChainId"
  }

  $settlementCountBefore =
    [uint64]((Invoke-CastCall $settlements "settlementCount()(uint256)") -split " ")[0]
  if ($settlementCountBefore -ne 0) {
    throw "A lifecycle settlement already exists; refusing to create a duplicate demo."
  }

  $eurcBalance =
    [uint64]((Invoke-CastCall $eurc "balanceOf(address)(uint256)" @($ExpectedAddress)) -split " ")[0]
  if ($eurcBalance -lt $tradeAmount) {
    throw "At least 1 EURC is required. Request EURC from https://faucet.circle.com/ first."
  }

  $securePassword = Read-Host "Foundry keystore password" -AsSecureString
  $passwordPointer =
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
  $plainPassword =
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)

  $actualAddress =
    ($plainPassword | & $cast wallet address --account $Account | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw "Could not unlock Foundry account $Account." }
  if ($actualAddress.ToLowerInvariant() -ne $ExpectedAddress.ToLowerInvariant()) {
    throw "Signer mismatch: expected $ExpectedAddress, received $actualAddress."
  }

  $isProvider =
    (Invoke-CastCall $providers "isActiveProvider(address)(bool)" @($ExpectedAddress)) -eq "true"
  if (-not $isProvider) {
    $providerUri = "https://quotemesh.vercel.app/providers"
    $profileHash = (& $cast keccak $providerUri | Out-String).Trim()
    Invoke-CastSend "register-provider" $providers "registerProvider(string,bytes32)" `
      @($providerUri, $profileHash) | Out-Null
  }

  $availableBefore =
    [uint64]((Invoke-CastCall $vault "availableBalanceOf(address,address)(uint256)" `
      @($ExpectedAddress, $usdc)) -split " ")[0]
  $reservedBefore =
    [uint64]((Invoke-CastCall $vault "reservedBalanceOf(address,address)(uint256)" `
      @($ExpectedAddress, $usdc)) -split " ")[0]
  $providerUsdcBefore = $availableBefore + $reservedBefore
  if ($providerUsdcBefore -gt $depositAmount) {
    throw "Provider USDC balance exceeds the lifecycle target; refusing an ambiguous run."
  }
  if ($providerUsdcBefore -lt $depositAmount) {
    $amountToDeposit = $depositAmount - $providerUsdcBefore
    Invoke-CastSend "approve-usdc" $usdc "approve(address,uint256)" `
      @($vault, $amountToDeposit.ToString()) | Out-Null
    Invoke-CastSend "deposit-usdc" $vault "deposit(address,uint256)" `
      @($usdc, $amountToDeposit.ToString()) | Out-Null
  }

  $rfqId =
    [uint64]((Invoke-CastCall $market "nextRFQId()(uint256)") -split " ")[0]
  $latestBlock = (& $cast block latest --field timestamp --rpc-url $rpc | Out-String).Trim()
  $latestTimestamp = if ($latestBlock -like "0x*") {
    [Convert]::ToUInt64(($latestBlock -replace "^0x", ""), 16)
  } else {
    [uint64](($latestBlock -split " ")[0])
  }
  $rfqExpiry = $latestTimestamp + 3600
  $rfqMetadataUri = "https://quotemesh.vercel.app/rfqs"
  $rfqMetadataHash = (& $cast keccak $rfqMetadataUri | Out-String).Trim()
  Invoke-CastSend "create-rfq" $market `
    "createRFQ(address,address,uint256,uint256,uint64,uint8,address[],bytes32,string)" `
    @(
      $eurc,
      $usdc,
      $tradeAmount.ToString(),
      $tradeAmount.ToString(),
      $rfqExpiry.ToString(),
      "0",
      "[]",
      $rfqMetadataHash,
      $rfqMetadataUri
    ) | Out-Null

  $quoteId =
    [uint64]((Invoke-CastCall $market "nextQuoteId()(uint256)") -split " ")[0]
  $providerReference =
    (& $cast keccak "QuoteMesh Arc Testnet lifecycle 1" | Out-String).Trim()
  $quoteExpiry = $latestTimestamp + 1800
  Invoke-CastSend "submit-quote" $market "submitQuote(uint256,uint256,uint64,bytes32)" `
    @(
      $rfqId.ToString(),
      $tradeAmount.ToString(),
      $quoteExpiry.ToString(),
      $providerReference
    ) | Out-Null

  Invoke-CastSend "approve-eurc" $eurc "approve(address,uint256)" `
    @($vault, $tradeAmount.ToString()) | Out-Null
  Invoke-CastSend "accept-quote" $market "acceptQuote(uint256,uint256,uint256)" `
    @($rfqId.ToString(), $quoteId.ToString(), $tradeAmount.ToString()) | Out-Null

  $settlementCountAfter =
    [uint64]((Invoke-CastCall $settlements "settlementCount()(uint256)") -split " ")[0]
  if ($settlementCountAfter -ne ($settlementCountBefore + 1)) {
    throw "Settlement receipt count did not increment exactly once."
  }

  $usdcAvailable =
    [uint64]((Invoke-CastCall $vault "availableBalanceOf(address,address)(uint256)" `
      @($ExpectedAddress, $usdc)) -split " ")[0]
  $usdcReserved =
    [uint64]((Invoke-CastCall $vault "reservedBalanceOf(address,address)(uint256)" `
      @($ExpectedAddress, $usdc)) -split " ")[0]
  $eurcAvailable =
    [uint64]((Invoke-CastCall $vault "availableBalanceOf(address,address)(uint256)" `
      @($ExpectedAddress, $eurc)) -split " ")[0]
  $eurcReserved =
    [uint64]((Invoke-CastCall $vault "reservedBalanceOf(address,address)(uint256)" `
      @($ExpectedAddress, $eurc)) -split " ")[0]
  $usdcSolvent = Invoke-CastCall $vault "isSolvent(address)(bool)" @($usdc)
  $eurcSolvent = Invoke-CastCall $vault "isSolvent(address)(bool)" @($eurc)
  if ($usdcReserved -ne 0 -or $eurcReserved -ne 0) {
    throw "A reservation remained after settlement."
  }
  if ($usdcSolvent -ne "true" -or $eurcSolvent -ne "true") {
    throw "Vault solvency check failed after settlement."
  }

  $result = [ordered]@{
    status = "success"
    network = "Arc Testnet"
    chainId = [uint64]$chainId
    operator = $ExpectedAddress
    relationship = "self-controlled taker and provider"
    rfqId = $rfqId
    quoteId = $quoteId
    settlementCount = $settlementCountAfter
    transactions = $transactions
    finalProviderLiquidity = [ordered]@{
      usdcAvailable = $usdcAvailable
      usdcReserved = $usdcReserved
      eurcAvailable = $eurcAvailable
      eurcReserved = $eurcReserved
    }
    vaultSolvent = [ordered]@{
      usdc = $true
      eurc = $true
    }
  }
  $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8
  Write-Host "Live lifecycle completed and independently checked." -ForegroundColor Green
  Write-Host "RFQ ID: $rfqId; Quote ID: $quoteId; Settlement count: $settlementCountAfter"
} finally {
  $plainPassword = $null
  if ($passwordPointer -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
  }
  $securePassword = $null
  Stop-Transcript | Out-Null
}
