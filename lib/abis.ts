import { parseAbi } from "viem";

export const erc20Abi = parseAbi([
  "function balanceOf(address account) view returns (uint256)",
  "function allowance(address owner,address spender) view returns (uint256)",
  "function approve(address spender,uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
]);

export const providerRegistryAbi = parseAbi([
  "function registerProvider(string metadataURI,bytes32 profileHash)",
  "function updateProviderProfile(string metadataURI,bytes32 profileHash)",
  "function pauseMyProviderAccount()",
  "function resumeMyProviderAccount()",
  "function isActiveProvider(address provider) view returns (bool)",
  "event ProviderRegistered(address indexed provider,string metadataURI,bytes32 indexed profileHash)",
  "event ProviderProfileUpdated(address indexed provider,string metadataURI,bytes32 indexed profileHash)",
  "event ProviderStatusUpdated(address indexed provider,bool active)",
  "event ProviderVerificationUpdated(address indexed provider,bool quoteMeshVerified)",
]);

export const liquidityVaultAbi = parseAbi([
  "function deposit(address token,uint256 amount)",
  "function withdraw(address token,uint256 amount,address recipient)",
  "function availableBalanceOf(address provider,address token) view returns (uint256)",
  "function reservedBalanceOf(address provider,address token) view returns (uint256)",
  "function totalLiability(address token) view returns (uint256)",
  "function actualBalance(address token) view returns (uint256)",
  "event LiquidityDeposited(address indexed provider,address indexed token,uint256 amount)",
  "event LiquidityWithdrawn(address indexed provider,address indexed token,address indexed recipient,uint256 amount)",
  "event LiquidityReserved(address indexed provider,address indexed token,uint256 amount)",
  "event LiquidityReleased(address indexed provider,address indexed token,uint256 amount)",
  "event ProtocolFeeAccrued(address indexed feeRecipient,address indexed token,uint256 amount)",
]);

export const rfqMarketAbi = parseAbi([
  "function createRFQ(address sellToken,address buyToken,uint256 sellAmount,uint256 minBuyAmount,uint64 expiresAt,uint8 accessMode,address[] invitedProviders,bytes32 metadataHash,string metadataURI) returns (uint256)",
  "function cancelRFQ(uint256 rfqId)",
  "function expireRFQ(uint256 rfqId)",
  "function submitQuote(uint256 rfqId,uint256 buyAmount,uint64 expiresAt,bytes32 providerReference) returns (uint256)",
  "function replaceQuote(uint256 quoteId,uint256 newBuyAmount,uint64 newExpiresAt,bytes32 newReference)",
  "function cancelQuote(uint256 quoteId)",
  "function releaseQuote(uint256 quoteId)",
  "function acceptQuote(uint256 rfqId,uint256 quoteId,uint256 minimumExpectedBuyAmount) returns (bytes32)",
  "event RFQCreated(uint256 indexed rfqId,address indexed taker,address indexed sellToken,address buyToken,uint256 sellAmount,uint256 minBuyAmount,uint64 expiresAt,uint8 accessMode,bytes32 metadataHash)",
  "event RFQCancelled(uint256 indexed rfqId,address indexed taker)",
  "event RFQExpired(uint256 indexed rfqId)",
  "event QuoteSubmitted(uint256 indexed quoteId,uint256 indexed rfqId,address indexed provider,uint256 buyAmount,uint64 expiresAt,bytes32 providerReference)",
  "event QuoteReplaced(uint256 indexed quoteId,uint256 previousBuyAmount,uint256 newBuyAmount,uint64 newExpiresAt,bytes32 providerReference)",
  "event QuoteCancelled(uint256 indexed quoteId,uint256 indexed rfqId,address indexed provider)",
  "event QuoteReleased(uint256 indexed quoteId,uint256 indexed rfqId,address indexed provider,uint256 amount)",
  "event TradeSettled(bytes32 indexed tradeId,uint256 indexed rfqId,uint256 indexed quoteId,address taker,address provider,address sellToken,address buyToken,uint256 sellAmount,uint256 buyAmount,uint256 feeAmount)",
]);

export const settlementRegistryAbi = parseAbi([
  "function settlementCount() view returns (uint256)",
  "function getSettlement(bytes32 tradeId) view returns ((bytes32 tradeId,uint256 rfqId,uint256 quoteId,address taker,address provider,address sellToken,address buyToken,uint256 sellAmount,uint256 buyAmount,uint256 feeAmount,uint64 settledAt))",
  "event SettlementRecorded(bytes32 indexed tradeId,uint256 indexed rfqId,uint256 indexed quoteId,address taker,address provider,address sellToken,address buyToken,uint256 sellAmount,uint256 buyAmount,uint256 feeAmount,uint64 settledAt)",
]);

export const multicall3FromAbi = parseAbi([
  "function aggregate3((address target,bool allowFailure,bytes callData)[] calls) payable returns ((bool success,bytes returnData)[] returnData)",
]);

export const memoAbi = parseAbi([
  "function memo(address target,bytes callData,bytes32 memoId,bytes memo) payable returns (bytes returnData)",
  "event Memo(address indexed sender,address indexed target,bytes32 callDataHash,bytes32 indexed memoId,bytes memo,uint256 memoIndex)",
]);
