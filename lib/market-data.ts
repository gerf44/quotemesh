import {
  createPublicClient,
  decodeEventLog,
  formatUnits,
  http,
  type Address,
  type Hex,
} from "viem";
import { ARC } from "./network";
import { getDeployment, publicConfig } from "./deployment";
import {
  liquidityVaultAbi,
  providerRegistryAbi,
  rfqMarketAbi,
  settlementRegistryAbi,
} from "./abis";

export type RecentSettlement = {
  tradeId: Hex;
  rfqId: bigint;
  quoteId: bigint;
  provider: Address;
  sellToken: Address;
  buyToken: Address;
  sellAmount: bigint;
  buyAmount: bigint;
};

export type OpenRFQSummary = {
  rfqId: bigint;
  taker: Address;
  sellToken: Address;
  buyToken: Address;
  sellAmount: bigint;
  minBuyAmount: bigint;
  expiresAt: bigint;
  accessMode: number;
};

export type MarketSnapshot = {
  deploymentReady: boolean;
  rpcOnline: boolean;
  indexedTo: bigint | null;
  activeRFQs: number;
  activeProviders: number;
  settledTrades: number;
  liquiditySummary: string;
  usdcSellVolume: string;
  openRFQs: OpenRFQSummary[];
  activeProviderAddresses: Address[];
  recentSettlements: RecentSettlement[];
  warning?: string;
};

const empty: MarketSnapshot = {
  deploymentReady: false,
  rpcOnline: false,
  indexedTo: null,
  activeRFQs: 0,
  activeProviders: 0,
  settledTrades: 0,
  liquiditySummary: "0 USDC · 0 EURC",
  usdcSellVolume: "0",
  openRFQs: [],
  activeProviderAddresses: [],
  recentSettlements: [],
};

export async function getMarketSnapshot(): Promise<MarketSnapshot> {
  const deployment = getDeployment();
  if (!deployment) {
    return {
      ...empty,
      warning: "QuoteMesh contracts are not configured. Showing honest zero-state data.",
    };
  }

  try {
    const client = createPublicClient({
      chain: ARC.chain,
      transport: http(publicConfig.rpcUrl, { timeout: 12_000 }),
    });
    const indexedTo = await client.getBlockNumber();
    const [
      rpcChainId,
      latestBlock,
      marketLogs,
      providerLogs,
      vaultLogs,
      settlementLogs,
      usdcBalance,
      eurcBalance,
    ] =
      await Promise.all([
        client.getChainId(),
        client.getBlock({ blockNumber: indexedTo }),
        client.getLogs({
          address: deployment.rfqMarket,
          fromBlock: deployment.deploymentBlock,
          toBlock: indexedTo,
        }),
        client.getLogs({
          address: deployment.providerRegistry,
          fromBlock: deployment.deploymentBlock,
          toBlock: indexedTo,
        }),
        client.getLogs({
          address: deployment.liquidityVault,
          fromBlock: deployment.deploymentBlock,
          toBlock: indexedTo,
        }),
        client.getLogs({
          address: deployment.settlementRegistry,
          fromBlock: deployment.deploymentBlock,
          toBlock: indexedTo,
        }),
        client.readContract({
          address: deployment.liquidityVault,
          abi: liquidityVaultAbi,
          functionName: "actualBalance",
          args: [ARC.usdc],
        }),
        client.readContract({
          address: deployment.liquidityVault,
          abi: liquidityVaultAbi,
          functionName: "actualBalance",
          args: [ARC.eurc],
        }),
      ]);
    if (rpcChainId !== ARC.chainId) {
      throw new Error(`RPC chain mismatch: expected ${ARC.chainId}, received ${rpcChainId}`);
    }

    const rfqStates = new Map<bigint, OpenRFQSummary & { closed: boolean }>();
    const providers = new Map<string, { address: Address; active: boolean }>();
    const recentSettlements: RecentSettlement[] = [];
    const settledTradeIds = new Set<string>();
    let usdcSellVolume = 0n;

    for (const log of marketLogs) {
      try {
        const decoded = decodeEventLog({ abi: rfqMarketAbi, data: log.data, topics: log.topics });
        const args = decoded.args as Record<string, unknown>;
        if (decoded.eventName === "RFQCreated") {
          rfqStates.set(args.rfqId as bigint, {
            rfqId: args.rfqId as bigint,
            taker: args.taker as Address,
            sellToken: args.sellToken as Address,
            buyToken: args.buyToken as Address,
            sellAmount: args.sellAmount as bigint,
            minBuyAmount: args.minBuyAmount as bigint,
            expiresAt: args.expiresAt as bigint,
            accessMode: Number(args.accessMode),
            closed: false,
          });
        }
        if (
          decoded.eventName === "RFQCancelled" ||
          decoded.eventName === "RFQExpired" ||
          decoded.eventName === "TradeSettled"
        ) {
          const rfqId = args.rfqId as bigint;
          const existing = rfqStates.get(rfqId);
          if (existing) rfqStates.set(rfqId, { ...existing, closed: true });
        }
        if (decoded.eventName === "TradeSettled") {
          const tradeId = args.tradeId as Hex;
          if (settledTradeIds.has(tradeId.toLowerCase())) continue;
          settledTradeIds.add(tradeId.toLowerCase());
          const sellToken = args.sellToken as Address;
          const buyToken = args.buyToken as Address;
          if (sellToken.toLowerCase() === ARC.usdc.toLowerCase()) {
            usdcSellVolume += args.sellAmount as bigint;
          }
          recentSettlements.push({
            tradeId,
            rfqId: args.rfqId as bigint,
            quoteId: args.quoteId as bigint,
            provider: args.provider as Address,
            sellToken,
            buyToken,
            sellAmount: args.sellAmount as bigint,
            buyAmount: args.buyAmount as bigint,
          });
        }
      } catch {
        // Contract-address filtering plus strict ABI decoding prevents foreign logs entering stats.
      }
    }

    for (const log of providerLogs) {
      try {
        const decoded = decodeEventLog({
          abi: providerRegistryAbi,
          data: log.data,
          topics: log.topics,
        });
        if (decoded.eventName === "ProviderRegistered") {
          const args = decoded.args as Record<string, unknown>;
          const provider = args.provider as Address;
          providers.set(provider.toLowerCase(), { address: provider, active: true });
        }
        if (decoded.eventName === "ProviderStatusUpdated") {
          const args = decoded.args as Record<string, unknown>;
          const provider = args.provider as Address;
          providers.set(provider.toLowerCase(), {
            address: provider,
            active: args.active as boolean,
          });
        }
      } catch {
        // Ignore unknown future events.
      }
    }

    // Decode once so malformed/foreign logs cannot enter the live snapshot.
    for (const log of [...vaultLogs, ...settlementLogs]) {
      try {
        decodeEventLog({
          abi: log.address === deployment.liquidityVault ? liquidityVaultAbi : settlementRegistryAbi,
          data: log.data,
          topics: log.topics,
        });
      } catch {
        // Ignore unknown future events.
      }
    }

    const openRFQs = [...rfqStates.values()]
      .filter((state) => !state.closed && state.expiresAt > latestBlock.timestamp)
      .sort((a, b) => (a.rfqId < b.rfqId ? 1 : -1))
      .map((state) => ({
        rfqId: state.rfqId,
        taker: state.taker,
        sellToken: state.sellToken,
        buyToken: state.buyToken,
        sellAmount: state.sellAmount,
        minBuyAmount: state.minBuyAmount,
        expiresAt: state.expiresAt,
        accessMode: state.accessMode,
      }));
    const activeProviderAddresses = [...providers.values()]
      .filter((provider) => provider.active)
      .map((provider) => provider.address);

    return {
      deploymentReady: true,
      rpcOnline: true,
      indexedTo,
      activeRFQs: openRFQs.length,
      activeProviders: activeProviderAddresses.length,
      settledTrades: recentSettlements.length,
      liquiditySummary: `${formatUnits(usdcBalance, 6)} USDC · ${formatUnits(eurcBalance, 6)} EURC`,
      usdcSellVolume: formatUnits(usdcSellVolume, 6),
      openRFQs,
      activeProviderAddresses,
      recentSettlements: recentSettlements.slice(-8).reverse(),
    };
  } catch (error) {
    return {
      ...empty,
      deploymentReady: true,
      warning: error instanceof Error ? `Arc RPC unavailable: ${error.message}` : "Arc RPC unavailable",
    };
  }
}
