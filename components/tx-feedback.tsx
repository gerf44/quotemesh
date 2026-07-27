"use client";

import type { Hash } from "viem";
import type { TxStatus } from "./use-arc-transaction";
import { ARC } from "@/lib/network";

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
    </div>
  );
}
