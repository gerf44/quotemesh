import { notFound } from "next/navigation";
import { isHex, type Hex } from "viem";
import { PageShell } from "@/components/page-shell";
import { EmptyState, Metric, StatusPill } from "@/components/ui";
import { getDeployment } from "@/lib/deployment";
import { getReceipt } from "@/lib/receipt";
import { ARC } from "@/lib/network";
import { formatTokenAmount } from "@/lib/token-display";

export const dynamic = "force-dynamic";

export default async function TradeReceiptPage({ params }: { params: Promise<{ tradeId: string }> }) {
  const { tradeId } = await params;
  if (!isHex(tradeId) || tradeId.length !== 66) notFound();
  const receipt = await getReceipt(tradeId as Hex);
  const deployment = getDeployment();
  return (
    <PageShell
      eyebrow="Settlement receipt"
      title="Atomic trade confirmation"
      copy="An immutable QuoteMesh protocol record. This is not a regulated bank or legal FX confirmation."
      actions={<StatusPill tone={receipt ? "positive" : "warning"}>{receipt ? "Final" : "Not found"}</StatusPill>}
    >
      {!receipt ? (
        <section className="panel">
          <EmptyState title="Receipt unavailable" copy="The trade ID is not present in the configured SettlementRegistry, or no deployment is configured." />
        </section>
      ) : (
        <>
          <section className="metrics-grid">
            <Metric label="Sell amount" value={formatTokenAmount(receipt.sellAmount, receipt.sellToken)} />
            <Metric label="Buy amount" value={formatTokenAmount(receipt.buyAmount, receipt.buyToken)} />
            <Metric label="Protocol fee" value={formatTokenAmount(receipt.feeAmount, receipt.sellToken)} />
            <Metric label="Settled" value={new Date(Number(receipt.settledAt) * 1000).toISOString()} />
          </section>
          <section className="panel section-copy" style={{ marginTop: "1rem" }}>
            <h2>Receipt fields</h2>
            <p className="mono">Trade ID: {receipt.tradeId}</p>
            <p className="mono">RFQ #{receipt.rfqId.toString()} · Quote #{receipt.quoteId.toString()}</p>
            <p className="mono">Taker: {receipt.taker}</p>
            <p className="mono">Provider: {receipt.provider}</p>
            <p className="mono">Network: Arc Testnet ({ARC.chainId})</p>
            {deployment && (
              <p className="mono">
                Contracts: <a href={`${ARC.explorerUrl}/address/${deployment.rfqMarket}`}>RFQMarket</a>
                {" · "}<a href={`${ARC.explorerUrl}/address/${deployment.liquidityVault}`}>LiquidityVault</a>
                {" · "}<a href={`${ARC.explorerUrl}/address/${deployment.settlementRegistry}`}>SettlementRegistry</a>
              </p>
            )}
            <a
              className="button"
              download={`quotemesh-${receipt.tradeId}.json`}
              href={`data:application/json,${encodeURIComponent(JSON.stringify(receipt, (_, value) => typeof value === "bigint" ? value.toString() : value, 2))}`}
            >
              Export JSON
            </a>
          </section>
        </>
      )}
    </PageShell>
  );
}
