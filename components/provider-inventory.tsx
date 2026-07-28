"use client";

import { formatUnits, zeroAddress } from "viem";
import { useAccount, useReadContract } from "wagmi";
import { liquidityVaultAbi, providerRegistryAbi } from "@/lib/abis";
import { getDeployment } from "@/lib/deployment";
import { ARC } from "@/lib/network";
import { EmptyState } from "./ui";

function amount(value: bigint | undefined) {
  return value === undefined ? "—" : formatUnits(value, 6);
}

export function ProviderInventory() {
  const deployment = getDeployment();
  const { address, chainId, isConnected } = useAccount();
  const enabled = Boolean(deployment && address && chainId === ARC.chainId);
  const provider = address ?? zeroAddress;
  const vault = deployment?.liquidityVault ?? zeroAddress;
  const registry = deployment?.providerRegistry ?? zeroAddress;
  const query = { enabled, refetchInterval: 10_000 } as const;

  const active = useReadContract({
    address: registry,
    abi: providerRegistryAbi,
    functionName: "isActiveProvider",
    args: [provider],
    chainId: ARC.chainId,
    query,
  });
  const usdcAvailable = useReadContract({
    address: vault,
    abi: liquidityVaultAbi,
    functionName: "availableBalanceOf",
    args: [provider, ARC.usdc],
    chainId: ARC.chainId,
    query,
  });
  const usdcReserved = useReadContract({
    address: vault,
    abi: liquidityVaultAbi,
    functionName: "reservedBalanceOf",
    args: [provider, ARC.usdc],
    chainId: ARC.chainId,
    query,
  });
  const eurcAvailable = useReadContract({
    address: vault,
    abi: liquidityVaultAbi,
    functionName: "availableBalanceOf",
    args: [provider, ARC.eurc],
    chainId: ARC.chainId,
    query,
  });
  const eurcReserved = useReadContract({
    address: vault,
    abi: liquidityVaultAbi,
    functionName: "reservedBalanceOf",
    args: [provider, ARC.eurc],
    chainId: ARC.chainId,
    query,
  });

  if (!isConnected) {
    return (
      <EmptyState
        title="Connect provider wallet"
        copy="Balances will be read directly from LiquidityVault."
      />
    );
  }
  if (chainId !== ARC.chainId) {
    return <EmptyState title="Switch to Arc Testnet" copy="Inventory is chain-specific." />;
  }

  const reads = [active, usdcAvailable, usdcReserved, eurcAvailable, eurcReserved];
  if (reads.some((read) => read.isPending)) {
    return <EmptyState title="Loading inventory" copy="Reading current Arc contract state." />;
  }
  if (reads.some((read) => read.isError)) {
    return (
      <EmptyState
        title="Inventory unavailable"
        copy="The Arc read failed. No balance is being inferred."
      />
    );
  }

  return (
    <div className="provider-inventory">
      <div className="inventory-status">
        <span>Provider status</span>
        <strong>{active.data ? "Active" : "Not registered or inactive"}</strong>
      </div>
      <div className="inventory-asset">
        <strong>USDC</strong>
        <span>Available {amount(usdcAvailable.data)}</span>
        <span>Reserved {amount(usdcReserved.data)}</span>
      </div>
      <div className="inventory-asset">
        <strong>EURC</strong>
        <span>Available {amount(eurcAvailable.data)}</span>
        <span>Reserved {amount(eurcReserved.data)}</span>
      </div>
    </div>
  );
}
