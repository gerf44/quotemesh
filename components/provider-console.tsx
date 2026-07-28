"use client";

import { useState } from "react";
import { formatUnits, keccak256, parseUnits, stringToHex, zeroAddress } from "viem";
import { useAccount, useReadContract } from "wagmi";
import { erc20Abi, liquidityVaultAbi, providerRegistryAbi, rfqMarketAbi } from "@/lib/abis";
import { getDeployment } from "@/lib/deployment";
import { isPositiveInteger, isPositiveTokenAmount } from "@/lib/input";
import { ARC, TOKENS } from "@/lib/network";
import { useArcTransaction } from "./use-arc-transaction";
import { TxFeedback } from "./tx-feedback";

type Action = "register" | "deposit" | "withdraw" | "quote" | "replace" | "cancel" | "release";

export function ProviderConsole() {
  const deployment = getDeployment();
  const { address, chainId, isConnected } = useAccount();
  const [action, setAction] = useState<Action>("register");
  const [token, setToken] = useState<"USDC" | "EURC">("EURC");
  const [amount, setAmount] = useState("");
  const [id, setId] = useState("");
  const [duration, setDuration] = useState("15");
  const [metadata, setMetadata] = useState("ipfs://");
  const tx = useArcTransaction();
  const onArc = chainId === ARC.chainId;
  const selectedToken = TOKENS[token];
  const depositAmount =
    action === "deposit" && isPositiveTokenAmount(amount) ? parseUnits(amount, 6) : null;
  const balanceRead = useReadContract({
    address: selectedToken.address,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address ?? zeroAddress],
    chainId: ARC.chainId,
    query: {
      enabled: action === "deposit" && Boolean(address) && onArc,
      refetchInterval: 10_000,
    },
  });
  const allowanceRead = useReadContract({
    address: selectedToken.address,
    abi: erc20Abi,
    functionName: "allowance",
    args: [address ?? zeroAddress, deployment?.liquidityVault ?? zeroAddress],
    chainId: ARC.chainId,
    query: {
      enabled: action === "deposit" && Boolean(address && deployment) && onArc,
      refetchInterval: 10_000,
    },
  });
  const depositReadError = balanceRead.isError || allowanceRead.isError;
  const depositBalanceReady =
    action !== "deposit" ||
    (!balanceRead.isPending &&
      !allowanceRead.isPending &&
      !depositReadError &&
      balanceRead.data !== undefined &&
      allowanceRead.data !== undefined);
  const insufficientDepositBalance =
    depositAmount !== null &&
    balanceRead.data !== undefined &&
    balanceRead.data < depositAmount;
  const needsAmount =
    action === "deposit" || action === "withdraw" || action === "quote" || action === "replace";
  const needsId =
    action === "quote" || action === "replace" || action === "cancel" || action === "release";
  const actionValid =
    (!needsAmount || isPositiveTokenAmount(amount)) &&
    (!needsId || isPositiveInteger(id)) &&
    depositBalanceReady &&
    !insufficientDepositBalance &&
    (action !== "register" || (metadata.length > 0 && metadata.length <= 256));

  async function execute() {
    if (!deployment || !address || !onArc || !actionValid || tx.busy) return;
    const expiry = BigInt(Math.floor(Date.now() / 1000) + Number(duration) * 60);
    if (action === "register") {
      return tx.execute({
        address: deployment.providerRegistry,
        abi: providerRegistryAbi,
        functionName: "registerProvider",
        args: [metadata, keccak256(stringToHex(metadata))],
      });
    }
    if (action === "deposit") {
      const parsedAmount = parseUnits(amount, 6);
      if (balanceRead.data === undefined || balanceRead.data < parsedAmount) return null;
      if (allowanceRead.data === undefined || allowanceRead.data < parsedAmount) {
        const approval = await tx.execute({
          address: selectedToken.address,
          abi: erc20Abi,
          functionName: "approve",
          args: [deployment.liquidityVault, parsedAmount],
        });
        if (!approval) return null;
      }
      const deposit = await tx.execute({
        address: deployment.liquidityVault,
        abi: liquidityVaultAbi,
        functionName: "deposit",
        args: [selectedToken.address, parsedAmount],
      });
      if (deposit) {
        await Promise.all([balanceRead.refetch(), allowanceRead.refetch()]);
      }
      return deposit;
    }
    if (action === "withdraw") {
      return tx.execute({
        address: deployment.liquidityVault,
        abi: liquidityVaultAbi,
        functionName: "withdraw",
        args: [TOKENS[token].address, parseUnits(amount, 6), address],
      });
    }
    if (action === "quote") {
      return tx.execute({
        address: deployment.rfqMarket,
        abi: rfqMarketAbi,
        functionName: "submitQuote",
        args: [BigInt(id), parseUnits(amount, 6), expiry, keccak256(stringToHex(metadata))],
      });
    }
    if (action === "replace") {
      return tx.execute({
        address: deployment.rfqMarket,
        abi: rfqMarketAbi,
        functionName: "replaceQuote",
        args: [BigInt(id), parseUnits(amount, 6), expiry, keccak256(stringToHex(metadata))],
      });
    }
    return tx.execute({
      address: deployment.rfqMarket,
      abi: rfqMarketAbi,
      functionName: action === "cancel" ? "cancelQuote" : "releaseQuote",
      args: [BigInt(id)],
    });
  }

  return (
    <div className="form-grid">
      <label>
        Provider action
        <select value={action} onChange={(event) => setAction(event.target.value as Action)}>
          <option value="register">Register profile</option>
          <option value="deposit">Deposit liquidity</option>
          <option value="withdraw">Withdraw available</option>
          <option value="quote">Submit firm quote</option>
          <option value="replace">Replace quote</option>
          <option value="cancel">Cancel quote</option>
          <option value="release">Release stale reservation</option>
        </select>
      </label>
      {action === "register" ? (
        <label>
          Public metadata URI
          <input value={metadata} onChange={(event) => setMetadata(event.target.value)} />
        </label>
      ) : (
        <>
          {(action === "deposit" || action === "withdraw") && (
            <label>
              Asset
              <select value={token} onChange={(event) => setToken(event.target.value as "USDC" | "EURC")}>
                <option>EURC</option>
                <option>USDC</option>
              </select>
            </label>
          )}
          {(action === "quote" || action === "replace" || action === "cancel" || action === "release") && (
            <label>
              {action === "quote" ? "RFQ ID" : "Quote ID"}
              <input value={id} onChange={(event) => setId(event.target.value)} />
            </label>
          )}
          {(action === "deposit" || action === "withdraw" || action === "quote" || action === "replace") && (
            <label>
              Amount
              <input value={amount} onChange={(event) => setAmount(event.target.value)} />
              {action === "deposit" && (
                <span
                  className={`balance-hint ${insufficientDepositBalance ? "error-copy" : ""}`}
                >
                  {balanceRead.isPending
                    ? "Checking wallet balance…"
                    : balanceRead.isError
                      ? "Wallet balance check failed"
                    : balanceRead.data === undefined
                      ? "Wallet balance unavailable"
                      : `Wallet balance: ${formatUnits(balanceRead.data, 6)} ${token}`}
                </span>
              )}
            </label>
          )}
          {(action === "quote" || action === "replace") && (
            <>
              <label>
                Quote validity
                <select value={duration} onChange={(event) => setDuration(event.target.value)}>
                  <option value="5">5 minutes</option>
                  <option value="15">15 minutes</option>
                  <option value="30">30 minutes</option>
                </select>
              </label>
              <label>
                Provider reference
                <input value={metadata} onChange={(event) => setMetadata(event.target.value)} />
              </label>
            </>
          )}
        </>
      )}
      <button
        className="button dark"
        disabled={!deployment || !isConnected || !onArc || !actionValid || tx.busy}
        onClick={execute}
      >
        {!deployment
          ? "Contracts not deployed"
          : !isConnected
            ? "Connect provider wallet"
            : !onArc
              ? "Switch to Arc first"
              : action === "deposit" && depositReadError
                ? "Deposit checks unavailable"
                : action === "deposit" && !depositBalanceReady
                  ? "Checking deposit requirements"
                  : insufficientDepositBalance
                    ? `Insufficient ${token} balance`
              : tx.busy
                ? "Transaction in progress"
                : "Continue"}
      </button>
      <TxFeedback status={tx.status} hash={tx.hash} error={tx.error} />
    </div>
  );
}
