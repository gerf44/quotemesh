import { createPublicClient, http, type Hex } from "viem";
import { settlementRegistryAbi } from "./abis";
import { getDeployment, publicConfig } from "./deployment";
import { ARC } from "./network";

export async function getReceipt(tradeId: Hex) {
  const deployment = getDeployment();
  if (!deployment) return null;
  try {
    const client = createPublicClient({
      chain: ARC.chain,
      transport: http(publicConfig.rpcUrl, { timeout: 12_000 }),
    });
    const receipt = await client.readContract({
      address: deployment.settlementRegistry,
      abi: settlementRegistryAbi,
      functionName: "getSettlement",
      args: [tradeId],
    });
    return receipt.tradeId === `0x${"0".repeat(64)}` ? null : receipt;
  } catch {
    return null;
  }
}
