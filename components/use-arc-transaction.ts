"use client";

import { useCallback, useRef, useState } from "react";
import type { Abi, Address, Hash } from "viem";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import {
  ARC,
  ARC_WALLET_RPC_ERROR,
  isArcWalletRpcFailure,
} from "@/lib/network";

type Request = {
  address: Address;
  abi: Abi;
  functionName: string;
  args?: readonly unknown[];
};

export type TxStatus =
  | "idle"
  | "checking"
  | "wallet"
  | "pending"
  | "final"
  | "reverted"
  | "unknown"
  | "error";

function message(error: unknown, walletRequest = false) {
  if (!(error instanceof Error)) return "Unknown transaction error";
  const detailed = error as Error & { shortMessage?: string; details?: string };
  const errorText = detailed.shortMessage || detailed.details || error.message;
  if (walletRequest && isArcWalletRpcFailure(error.message)) {
    return ARC_WALLET_RPC_ERROR;
  }
  if (/user rejected|request rejected|rejected the request|4001/i.test(errorText)) {
    return "Transaction rejected in wallet.";
  }
  if (/transfer amount exceeds balance|insufficient balance/i.test(errorText)) {
    return "Insufficient token balance for this transaction.";
  }
  if (/transfer amount exceeds allowance|insufficient allowance/i.test(errorText)) {
    return "Token allowance is insufficient for this transaction.";
  }
  if (/insufficient funds/i.test(errorText)) {
    return "Insufficient USDC for gas or transaction value.";
  }
  return errorText.split("\n")[0];
}

export function useArcTransaction() {
  const { address: account } = useAccount();
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
      setStatus("checking");
      let transactionHash: Hash;
      if (publicClient && account) {
        try {
          await publicClient.simulateContract({
            ...request,
            account,
          } as never);
        } catch (caught) {
          setError(`Transaction would revert: ${message(caught)}`);
          setStatus("error");
          inFlight.current = false;
          return null;
        }
      }

      setStatus("wallet");
      try {
        transactionHash = await writeContractAsync({
          ...request,
          chainId: ARC.chainId,
        } as never);
      } catch (caught) {
        setError(message(caught, true));
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
    [account, publicClient, writeContractAsync],
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
    busy: status === "checking" || status === "wallet" || status === "pending",
    reset,
  };
}
