"use client";

import { useCallback, useRef, useState } from "react";
import type { Abi, Address, Hash } from "viem";
import { usePublicClient, useWriteContract } from "wagmi";
import { ARC } from "@/lib/network";

type Request = {
  address: Address;
  abi: Abi;
  functionName: string;
  args?: readonly unknown[];
};

export type TxStatus =
  | "idle"
  | "wallet"
  | "pending"
  | "final"
  | "reverted"
  | "unknown"
  | "error";

function message(error: unknown) {
  if (!(error instanceof Error)) return "Unknown transaction error";
  if (/rejected|denied/i.test(error.message)) return "Transaction rejected in wallet.";
  if (/insufficient funds/i.test(error.message)) {
    return "Insufficient USDC for gas or transaction value.";
  }
  return error.message.split("\n")[0];
}

export function useArcTransaction() {
  const publicClient = usePublicClient({ chainId: ARC.chainId });
  const { writeContractAsync } = useWriteContract();
  const [status, setStatus] = useState<TxStatus>("idle");
  const [hash, setHash] = useState<Hash | null>(null);
  const [error, setError] = useState<string | null>(null);
  const inFlight = useRef(false);

  const execute = useCallback(
    async (request: Request) => {
      if (inFlight.current) return null;
      inFlight.current = true;
      setError(null);
      setHash(null);
      setStatus("wallet");
      let transactionHash: Hash;
      try {
        transactionHash = await writeContractAsync({
          ...request,
          chainId: ARC.chainId,
        } as never);
      } catch (caught) {
        setError(message(caught));
        setStatus("error");
        inFlight.current = false;
        return null;
      }

      setHash(transactionHash);
      setStatus("pending");
      if (!publicClient) {
        setError("Transaction submitted, but the Arc confirmation client is unavailable.");
        setStatus("unknown");
        inFlight.current = false;
        return null;
      }

      try {
        const receipt = await publicClient.waitForTransactionReceipt({ hash: transactionHash });
        if (receipt.status !== "success") {
          setError("Arc included the transaction, but execution reverted.");
          setStatus("reverted");
          inFlight.current = false;
          return null;
        }
        setStatus("final");
        inFlight.current = false;
        return transactionHash;
      } catch (caught) {
        setError(
          `Transaction submitted, but finality could not be confirmed: ${message(caught)}`,
        );
        setStatus("unknown");
        inFlight.current = false;
        return null;
      }
    },
    [publicClient, writeContractAsync],
  );

  const reset = () => {
    if (inFlight.current) return;
    setStatus("idle");
    setHash(null);
    setError(null);
  };

  return {
    execute,
    status,
    hash,
    error,
    busy: status === "wallet" || status === "pending",
    reset,
  };
}
