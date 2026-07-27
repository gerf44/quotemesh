"use client";

import { Cable, LogOut, TriangleAlert } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { numberToHex } from "viem";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { ARC, ARC_RPC_URLS } from "@/lib/network";

type WalletProvider = {
  request(args: { method: string; params?: readonly unknown[] }): Promise<unknown>;
};

type RpcState = "idle" | "checking" | "repairing" | "ready" | "blocked";

const arcChainIdHex = numberToHex(ARC.chainId);
const arcAddParameters = {
  chainId: arcChainIdHex,
  chainName: ARC.chain.name,
  nativeCurrency: ARC.chain.nativeCurrency,
  rpcUrls: [...ARC_RPC_URLS],
  blockExplorerUrls: [ARC.explorerUrl],
} as const;

function isUserRejection(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const candidate = error as { code?: number; message?: string };
  return candidate.code === 4001 || /user rejected|request rejected/i.test(candidate.message ?? "");
}

async function assertWalletRpc(provider: WalletProvider) {
  await provider.request({ method: "eth_blockNumber" });
}

async function requestWalletRpcRepair(provider: WalletProvider) {
  try {
    await provider.request({
      method: "wallet_updateEthereumChain",
      params: [
        {
          chainId: arcChainIdHex,
          chainName: ARC.chain.name,
          nativeCurrency: ARC.chain.nativeCurrency,
          rpcUrls: [...ARC_RPC_URLS],
          blockExplorerUrl: ARC.explorerUrl,
        },
      ],
    });
    await assertWalletRpc(provider);
    return;
  } catch (error) {
    if (isUserRejection(error)) throw error;
  }

  try {
    await provider.request({
      method: "wallet_addEthereumChain",
      params: [arcAddParameters],
    });
  } catch (error) {
    if (isUserRejection(error)) throw error;
  }

  await assertWalletRpc(provider);
}

function short(address: string) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function WalletButton() {
  const { address, chainId, connector, isConnected } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, switchChainAsync, isPending: switching } = useSwitchChain();
  const automaticAttempt = useRef<string | null>(null);
  const rpcCheckAttempt = useRef<string | null>(null);
  const [rpcState, setRpcState] = useState<RpcState>("idle");
  const [copied, setCopied] = useState(false);

  const repairWalletRpc = useCallback(async () => {
    if (!connector) return;
    setRpcState("repairing");
    try {
      const provider = (await connector.getProvider()) as WalletProvider;
      await requestWalletRpcRepair(provider);
      setRpcState("ready");
    } catch {
      setRpcState("blocked");
    }
  }, [connector]);

  useEffect(() => {
    if (!isConnected) {
      automaticAttempt.current = null;
      rpcCheckAttempt.current = null;
      return;
    }

    if (chainId === undefined) return;
    if (chainId === ARC.chainId) {
      automaticAttempt.current = null;
      return;
    }

    const attempt = `${address ?? "connected"}:${chainId}`;
    if (automaticAttempt.current === attempt) return;
    automaticAttempt.current = attempt;

    void switchChainAsync({ chainId: ARC.chainId }).catch(() => {
      // The wallet may require a user decision or reject programmatic switching.
      // The visible button below remains available as a manual retry.
    });
  }, [address, chainId, isConnected, switchChainAsync]);

  useEffect(() => {
    if (!isConnected || chainId !== ARC.chainId || !connector) return;

    const attempt = `${address ?? "connected"}:${connector.id}`;
    if (rpcCheckAttempt.current === attempt) return;
    rpcCheckAttempt.current = attempt;

    void (async () => {
      setRpcState("checking");
      try {
        const provider = (await connector.getProvider()) as WalletProvider;
        await assertWalletRpc(provider);
        setRpcState("ready");
      } catch {
        await repairWalletRpc();
      }
    })();
  }, [address, chainId, connector, isConnected, repairWalletRpc]);

  async function copyRpc() {
    try {
      await navigator.clipboard.writeText(ARC.walletRpcUrl);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }

  if (isConnected && chainId !== ARC.chainId) {
    return (
      <button
        className="wallet-button warning"
        onClick={() => switchChain({ chainId: ARC.chainId })}
        disabled={switching}
      >
        <TriangleAlert size={16} />
        {switching ? "Switching…" : "Switch to Arc"}
      </button>
    );
  }

  if (isConnected && address) {
    if (rpcState === "checking" || rpcState === "repairing") {
      return (
        <button className="wallet-button warning" disabled>
          <TriangleAlert size={16} />
          {rpcState === "checking" ? "Checking Arc RPC…" : "Repairing Arc RPC…"}
        </button>
      );
    }

    if (rpcState === "blocked") {
      return (
        <>
          <button className="wallet-button warning" onClick={repairWalletRpc}>
            <TriangleAlert size={16} />
            Repair Arc RPC
          </button>
          <aside className="rpc-wallet-alert" role="alert">
            <strong>Wallet Arc RPC is still blocked</strong>
            <p>
              This wallet did not update its saved Arc Testnet endpoint. Open wallet Settings →
              Networks → Arc Testnet, add and select:
            </p>
            <code>{ARC.walletRpcUrl}</code>
            <div>
              <button type="button" onClick={copyRpc}>
                {copied ? "RPC copied" : "Copy RPC"}
              </button>
              <button type="button" className="button ghost" onClick={() => disconnect()}>
                Disconnect
              </button>
            </div>
          </aside>
        </>
      );
    }

    return (
      <button className="wallet-button" onClick={() => disconnect()}>
        <span className="status-dot online" />
        {short(address)}
        <LogOut size={15} />
      </button>
    );
  }

  return (
    <button
      className="wallet-button primary"
      onClick={() => connectors[0] && connect({ connector: connectors[0] })}
      disabled={isPending || connectors.length === 0}
    >
      <Cable size={16} />
      {connectors.length === 0 ? "Install wallet" : isPending ? "Connecting…" : "Connect wallet"}
    </button>
  );
}
