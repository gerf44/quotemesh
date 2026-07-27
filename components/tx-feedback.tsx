"use client";

import { useState } from "react";
import type { Hash } from "viem";
import type { TxStatus } from "./use-arc-transaction";
import {
  ARC,
  ARC_WALLET_RPC_ERROR,
  isArcWalletRpcFailure,
} from "@/lib/network";

const labels: Record<TxStatus, string> = {
  idle: "Ready",
  wallet: "Waiting for wallet confirmation",
  pending: "Pending on Arc",
  final: "Transaction final on Arc",
  reverted: "Transaction reverted",
  unknown: "Confirmation unavailable",
  error: "Transaction failed",
};

export function TxFeedback({
  status,
  hash,
  error,
}: {
  status: TxStatus;
  hash: Hash | null;
  error: string | null;
}) {
  const [copied, setCopied] = useState(false);
  const walletRpcFailure =
    error === ARC_WALLET_RPC_ERROR || (error ? isArcWalletRpcFailure(error) : false);

  async function copyRpc() {
    try {
      await navigator.clipboard.writeText(ARC.walletRpcUrl);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }

  if (status === "idle") return null;
  return (
    <div
      className={`tx-state ${
        status === "error" || status === "reverted"
          ? "error"
          : status === "final"
            ? "success"
            : ""
      }`}
    >
      <strong>{labels[status]}</strong>
      {hash && (
        <>
          {" · "}
          <a href={`${ARC.explorerUrl}/tx/${hash}`} target="_blank" rel="noreferrer">
            {hash.slice(0, 10)}…{hash.slice(-8)}
          </a>
        </>
      )}
      {error && <div>{error}</div>}
      {walletRpcFailure && (
        <div className="rpc-recovery">
          <p>
            In your wallet, open Settings → Networks → Arc Testnet and replace the default RPC
            with <code>{ARC.walletRpcUrl}</code>. Then retry the transaction.
          </p>
          <div className="rpc-recovery-actions">
            <button type="button" onClick={copyRpc}>
              {copied ? "RPC copied" : "Copy working RPC"}
            </button>
            <a
              href="https://docs.arc.io/arc/references/rpc-endpoints"
              target="_blank"
              rel="noreferrer"
            >
              Official Arc RPC list
            </a>
          </div>
        </div>
      )}
    </div>
  );
}
