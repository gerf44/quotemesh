"use client";

import { useMemo, useState } from "react";
import { isAddress, keccak256, parseUnits, stringToHex } from "viem";
import { useAccount } from "wagmi";
import { getDeployment } from "@/lib/deployment";
import { TOKENS } from "@/lib/network";
import { rfqMarketAbi } from "@/lib/abis";
import { isPositiveTokenAmount } from "@/lib/input";
import { ARC } from "@/lib/network";
import { useArcTransaction } from "./use-arc-transaction";
import { TxFeedback } from "./tx-feedback";

export function CreateRFQForm() {
  const deployment = getDeployment();
  const { chainId, isConnected } = useAccount();
  const [sell, setSell] = useState<"USDC" | "EURC">("USDC");
  const [amount, setAmount] = useState("1000");
  const [minimum, setMinimum] = useState("900");
  const [minutes, setMinutes] = useState("30");
  const [accessMode, setAccessMode] = useState<"public" | "invite">("public");
  const [invites, setInvites] = useState("");
  const [reference, setReference] = useState("");
  const tx = useArcTransaction();
  const buy = sell === "USDC" ? "EURC" : "USDC";
  const invitedProviders = accessMode === "invite"
    ? invites.split(",").map((value) => value.trim()).filter(Boolean)
    : [];
  const invitesValid =
    accessMode === "public" ||
    (invitedProviders.length > 0 &&
      invitedProviders.length <= 16 &&
      invitedProviders.every((provider) => isAddress(provider)) &&
      new Set(invitedProviders.map((value) => value.toLowerCase())).size ===
        invitedProviders.length);
  const formValid =
    isPositiveTokenAmount(amount) && isPositiveTokenAmount(minimum) && invitesValid;
  const onArc = chainId === ARC.chainId;
  const rate = useMemo(() => {
    const sellNumber = Number(amount);
    const buyNumber = Number(minimum);
    return sellNumber > 0 && buyNumber > 0 ? (buyNumber / sellNumber).toFixed(6) : "—";
  }, [amount, minimum]);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!deployment || !formValid || !onArc) return;
    await tx.execute({
      address: deployment.rfqMarket,
      abi: rfqMarketAbi,
      functionName: "createRFQ",
      args: [
        TOKENS[sell].address,
        TOKENS[buy].address,
        parseUnits(amount, 6),
        parseUnits(minimum, 6),
        BigInt(Math.floor(Date.now() / 1000) + Number(minutes) * 60),
        accessMode === "public" ? 0 : 1,
        invitedProviders,
        reference ? keccak256(stringToHex(reference)) : `0x${"0".repeat(64)}`,
        "",
      ],
    });
  }

  return (
    <form className="form-grid" onSubmit={submit}>
      <div className="form-row">
        <label>
          Sell
          <select value={sell} onChange={(event) => setSell(event.target.value as "USDC" | "EURC")}>
            <option>USDC</option>
            <option>EURC</option>
          </select>
        </label>
        <label>
          Buy
          <input value={buy} disabled />
        </label>
      </div>
      <label>
        Exact sell amount
        <input inputMode="decimal" value={amount} onChange={(event) => setAmount(event.target.value)} />
      </label>
      <label>
        Minimum receive
        <input
          inputMode="decimal"
          value={minimum}
          onChange={(event) => setMinimum(event.target.value)}
        />
      </label>
      <div className="form-row">
        <label>
          Expires in
          <select value={minutes} onChange={(event) => setMinutes(event.target.value)}>
            <option value="10">10 minutes</option>
            <option value="30">30 minutes</option>
            <option value="60">1 hour</option>
            <option value="240">4 hours</option>
          </select>
        </label>
        <label>
          Access
          <select
            value={accessMode}
            onChange={(event) => setAccessMode(event.target.value as "public" | "invite")}
          >
            <option value="public">Public RFQ</option>
            <option value="invite">Invite-only</option>
          </select>
        </label>
      </div>
      {accessMode === "invite" && (
        <label>
          Invited provider addresses
          <textarea
            rows={3}
            placeholder="0x… , 0x…"
            value={invites}
            onChange={(event) => setInvites(event.target.value)}
          />
        </label>
      )}
      <label>
        Accounting reference (hashed onchain)
        <input
          maxLength={120}
          value={reference}
          onChange={(event) => setReference(event.target.value)}
          placeholder="Optional internal reference"
        />
      </label>
      <div className="notice">
        Minimum effective rate: <strong className="mono">{rate} {buy}/{sell}</strong>. Invite-only
        controls who may submit a quote. It does not hide transaction or trade information from the
        blockchain.
      </div>
      {!invitesValid && (
        <p className="notice">Provide 1–16 unique valid provider addresses.</p>
      )}
      <button
        className="button dark"
        disabled={!deployment || !isConnected || !onArc || !formValid || tx.busy}
      >
        {!deployment
          ? "Contracts not deployed"
          : !isConnected
            ? "Connect wallet first"
            : !onArc
              ? "Switch to Arc first"
              : tx.busy
                ? "Transaction in progress"
                : "Create RFQ"}
      </button>
      <TxFeedback status={tx.status} hash={tx.hash} error={tx.error} />
    </form>
  );
}
