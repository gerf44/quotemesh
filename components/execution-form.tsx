"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { useAccount } from "wagmi";
import { erc20Abi, rfqMarketAbi } from "@/lib/abis";
import { buildApproveAndAcceptBatch, buildMemoAcceptance } from "@/lib/arc-transactions";
import { getDeployment } from "@/lib/deployment";
import { isPositiveInteger, isPositiveTokenAmount } from "@/lib/input";
import { ARC, TOKENS } from "@/lib/network";
import { useArcTransaction } from "./use-arc-transaction";
import { TxFeedback } from "./tx-feedback";

export function ExecutionForm({ initialRfqId = "" }: { initialRfqId?: string }) {
  const deployment = getDeployment();
  const { address, chainId, isConnected } = useAccount();
  const [sell, setSell] = useState<"USDC" | "EURC">("USDC");
  const [rfqId, setRfqId] = useState(initialRfqId);
  const [quoteId, setQuoteId] = useState("");
  const [minimum, setMinimum] = useState("");
  const [sellAmount, setSellAmount] = useState("");
  const [reference, setReference] = useState("");
  const tx = useArcTransaction();
  const buy = sell === "USDC" ? "EURC" : "USDC";
  const onArc = chainId === ARC.chainId;
  const idsValid = isPositiveInteger(rfqId) && isPositiveInteger(quoteId);
  const minimumValid = isPositiveTokenAmount(minimum);
  const sellAmountValid = isPositiveTokenAmount(sellAmount);

  const blocked =
    !deployment || !isConnected || !onArc || !idsValid || !minimumValid || tx.busy;

  async function approve() {
    if (!deployment || !sellAmountValid || !onArc) return;
    await tx.execute({
      address: TOKENS[sell].address,
      abi: erc20Abi,
      functionName: "approve",
      args: [deployment.liquidityVault, parseUnits(sellAmount, 6)],
    });
  }

  async function direct() {
    if (!deployment || blocked) return;
    await tx.execute({
      address: deployment.rfqMarket,
      abi: rfqMarketAbi,
      functionName: "acceptQuote",
      args: [BigInt(rfqId), BigInt(quoteId), parseUnits(minimum, 6)],
    });
  }

  async function batch() {
    if (!deployment || blocked || !sellAmountValid) return;
    await tx.execute(
      buildApproveAndAcceptBatch({
        sellToken: TOKENS[sell].address,
        vault: deployment.liquidityVault,
        market: deployment.rfqMarket,
        sellAmount: parseUnits(sellAmount, 6),
        rfqId: BigInt(rfqId),
        quoteId: BigInt(quoteId),
        minimumBuyAmount: parseUnits(minimum, 6),
      }),
    );
  }

  async function memo() {
    if (!deployment || !address || blocked) return;
    await tx.execute(
      buildMemoAcceptance({
        market: deployment.rfqMarket,
        rfqId: BigInt(rfqId),
        quoteId: BigInt(quoteId),
        minimumBuyAmount: parseUnits(minimum, 6),
        actor: address,
        clientReference: reference,
      }),
    );
  }

  return (
    <div className="form-grid">
      <div className="form-row">
        <label>
          Sell asset
          <select value={sell} onChange={(event) => setSell(event.target.value as "USDC" | "EURC")}>
            <option>USDC</option>
            <option>EURC</option>
          </select>
        </label>
        <label>
          Buy asset
          <input value={buy} disabled />
        </label>
      </div>
      <div className="form-row">
        <label>
          RFQ ID
          <input inputMode="numeric" value={rfqId} onChange={(event) => setRfqId(event.target.value)} />
        </label>
        <label>
          Quote ID
          <input
            inputMode="numeric"
            value={quoteId}
            onChange={(event) => setQuoteId(event.target.value)}
          />
        </label>
      </div>
      <label>
        Minimum expected {buy}
        <input value={minimum} onChange={(event) => setMinimum(event.target.value)} />
      </label>
      <label>
        Exact sell {sell} (needed for approval/batch)
        <input value={sellAmount} onChange={(event) => setSellAmount(event.target.value)} />
      </label>
      <label>
        Optional trade reference
        <input value={reference} maxLength={120} onChange={(event) => setReference(event.target.value)} />
      </label>
      <button onClick={approve} disabled={blocked || !sellAmountValid}>1. Approve vault</button>
      <button className="button dark" onClick={direct} disabled={blocked}>Direct acceptance</button>
      <button className="button primary" onClick={batch} disabled={blocked || !sellAmountValid}>
        Arc batched approve + accept
      </button>
      <button onClick={memo} disabled={blocked}>
        Execute with Memo reference
      </button>
      <p className="notice">
        Memo and Multicall3From are separate execution modes and must each be called directly by an
        EOA. Smart contract wallets must use separate approval plus direct acceptance. Every mode
        checks the receipt status before displaying a final success state.
      </p>
      <TxFeedback status={tx.status} hash={tx.hash} error={tx.error} />
    </div>
  );
}
