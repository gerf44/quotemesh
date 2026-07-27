import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { createPublicClient, decodeEventLog, http, type Abi, type Address, type Hex } from "viem";
import { ARC } from "../lib/network";
import { getDeployment, publicConfig } from "../lib/deployment";
import {
  liquidityVaultAbi,
  providerRegistryAbi,
  rfqMarketAbi,
  settlementRegistryAbi,
} from "../lib/abis";

type StoredEvent = {
  id: string;
  chainId: number;
  address: Address;
  transactionHash: Hex;
  logIndex: number;
  blockNumber: string;
  eventName: string;
  args: Record<string, string>;
};

type State = {
  chainId: number;
  lastIndexedBlock: string;
  events: StoredEvent[];
};

const dataFile = join(process.cwd(), "indexer", "data", "events.json");
const reset = process.argv.includes("--reset");

function serializable(value: unknown): string {
  if (typeof value === "bigint") return value.toString();
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  if (Array.isArray(value)) return JSON.stringify(value.map(serializable));
  return JSON.stringify(value);
}

async function loadState(startBlock: bigint): Promise<State> {
  if (reset) return { chainId: ARC.chainId, lastIndexedBlock: (startBlock - 1n).toString(), events: [] };
  try {
    const parsed = JSON.parse(await readFile(dataFile, "utf8")) as State;
    if (parsed.chainId !== ARC.chainId) throw new Error("Indexer chain mismatch");
    if (!Array.isArray(parsed.events)) throw new Error("Indexer event cache is invalid");
    const lastIndexedBlock = BigInt(parsed.lastIndexedBlock);
    if (lastIndexedBlock < startBlock - 1n) {
      throw new Error("Indexer checkpoint predates the configured deployment block");
    }
    const unique = new Map(parsed.events.map((event) => [event.id, event]));
    return { ...parsed, events: [...unique.values()] };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    return { chainId: ARC.chainId, lastIndexedBlock: (startBlock - 1n).toString(), events: [] };
  }
}

async function saveState(state: State) {
  await mkdir(dirname(dataFile), { recursive: true });
  const temporary = `${dataFile}.tmp`;
  await writeFile(temporary, `${JSON.stringify(state, null, 2)}\n`, "utf8");
  await rename(temporary, dataFile);
}

async function retry<T>(operation: () => Promise<T>, attempts = 3): Promise<T> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, attempt * 750));
    }
  }
  throw lastError;
}

async function main() {
  const deployment = getDeployment();
  if (!deployment) throw new Error("Set every NEXT_PUBLIC_* QuoteMesh contract address first.");
  const client = createPublicClient({ chain: ARC.chain, transport: http(publicConfig.rpcUrl) });
  const latest = await retry(() => client.getBlockNumber());
  const state = await loadState(deployment.deploymentBlock);
  if (BigInt(state.lastIndexedBlock) > latest) {
    throw new Error("Indexer checkpoint is ahead of the Arc RPC head; reset explicitly");
  }
  await saveState(state);
  const known = new Set(state.events.map((event) => event.id));
  let fromBlock = BigInt(state.lastIndexedBlock) + 1n;

  const contracts: Array<{ address: Address; abi: Abi }> = [
    { address: deployment.providerRegistry, abi: providerRegistryAbi },
    { address: deployment.liquidityVault, abi: liquidityVaultAbi },
    { address: deployment.rfqMarket, abi: rfqMarketAbi },
    { address: deployment.settlementRegistry, abi: settlementRegistryAbi },
  ];

  while (fromBlock <= latest) {
    const toBlock = fromBlock + 4_999n > latest ? latest : fromBlock + 4_999n;
    for (const contract of contracts) {
      const logs = await retry(() =>
        client.getLogs({ address: contract.address, fromBlock, toBlock }),
      );
      for (const log of logs) {
        if (!log.transactionHash || log.logIndex === null || log.blockNumber === null) continue;
        const id = `${ARC.chainId}:${log.transactionHash}:${log.logIndex}:${log.address.toLowerCase()}`;
        if (known.has(id)) continue;
        try {
          const decoded = decodeEventLog({ abi: contract.abi, data: log.data, topics: log.topics });
          const rawArgs = decoded.args as unknown as Record<string, unknown>;
          state.events.push({
            id,
            chainId: ARC.chainId,
            address: log.address,
            transactionHash: log.transactionHash,
            logIndex: log.logIndex,
            blockNumber: log.blockNumber.toString(),
            eventName: decoded.eventName ?? "Unknown",
            args: Object.fromEntries(
              Object.entries(rawArgs).map(([key, value]) => [key, serializable(value)]),
            ),
          });
          known.add(id);
        } catch {
          // Ignore an unknown event from a future contract version; raw chain data remains available.
        }
      }
    }
    state.lastIndexedBlock = toBlock.toString();
    await saveState(state);
    fromBlock = toBlock + 1n;
  }

  console.log(`Indexed ${state.events.length} unique events through block ${state.lastIndexedBlock}.`);
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
