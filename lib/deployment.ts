import { getAddress, isAddress, zeroAddress, type Address } from "viem";
import { ARC } from "./network";

export type DeploymentConfig = {
  assetRegistry: Address;
  providerRegistry: Address;
  liquidityVault: Address;
  rfqMarket: Address;
  settlementRegistry: Address;
  deploymentBlock: bigint;
};

function address(value: string | undefined): Address | null {
  if (!value || !isAddress(value)) return null;
  const normalized = getAddress(value);
  return normalized === zeroAddress ? null : normalized;
}

function deploymentBlock(value: string | undefined): bigint | null {
  try {
    const parsed = BigInt(value || "0");
    return parsed >= 0n ? parsed : null;
  } catch {
    return null;
  }
}

export function getDeployment(): DeploymentConfig | null {
  const assetRegistry = address(process.env.NEXT_PUBLIC_ASSET_REGISTRY_ADDRESS);
  const providerRegistry = address(process.env.NEXT_PUBLIC_PROVIDER_REGISTRY_ADDRESS);
  const liquidityVault = address(process.env.NEXT_PUBLIC_LIQUIDITY_VAULT_ADDRESS);
  const rfqMarket = address(process.env.NEXT_PUBLIC_RFQ_MARKET_ADDRESS);
  const settlementRegistry = address(process.env.NEXT_PUBLIC_SETTLEMENT_REGISTRY_ADDRESS);
  const startBlock = deploymentBlock(process.env.NEXT_PUBLIC_DEPLOYMENT_BLOCK);
  if (
    !assetRegistry ||
    !providerRegistry ||
    !liquidityVault ||
    !rfqMarket ||
    !settlementRegistry ||
    startBlock === null
  ) {
    return null;
  }
  const configuredAddresses = [
    assetRegistry,
    providerRegistry,
    liquidityVault,
    rfqMarket,
    settlementRegistry,
  ];
  if (new Set(configuredAddresses).size !== configuredAddresses.length) return null;
  return {
    assetRegistry,
    providerRegistry,
    liquidityVault,
    rfqMarket,
    settlementRegistry,
    deploymentBlock: startBlock,
  };
}

export const publicConfig = {
  rpcUrl: process.env.NEXT_PUBLIC_ARC_RPC_URL || ARC.rpcUrl,
  explorerUrl: process.env.NEXT_PUBLIC_ARC_EXPLORER_URL || ARC.explorerUrl,
};
