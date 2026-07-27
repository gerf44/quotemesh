"use client";

import { Cable, LogOut, TriangleAlert } from "lucide-react";
import { useEffect, useRef } from "react";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { ARC } from "@/lib/network";

function short(address: string) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function WalletButton() {
  const { address, chainId, isConnected } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, switchChainAsync, isPending: switching } = useSwitchChain();
  const automaticAttempt = useRef<string | null>(null);

  useEffect(() => {
    if (!isConnected) {
      automaticAttempt.current = null;
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
