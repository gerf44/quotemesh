import Link from "next/link";
import { PageShell } from "@/components/page-shell";
import { EmptyState, Metric } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";
import { formatTokenAmount } from "@/lib/token-display";

export const dynamic = "force-dynamic";

export default async function TradesPage() {
  const snapshot = await getMarketSnapshot();
  return (
    <PageShell
      eyebrow="Settlement blotter"
      title="Final trades and immutable receipts."
      copy="Every row originates from a TradeSettled event and links to its SettlementRegistry record."
    >
      <section className="metrics-grid">
        <Metric label="Settled trades" value={String(snapshot.settledTrades)} />
        <Metric label="USDC sell volume" value={`${snapshot.usdcSellVolume} USDC`} />
        <Metric label="Network" value="Arc Testnet" />
        <Metric label="Finality" value="Pending → Final" />
      </section>
      <section className="panel" style={{ marginTop: "1rem" }}>
        <div className="panel-header"><h2>Trade blotter</h2><span className="mono">No sample fills</span></div>
        {snapshot.recentSettlements.length === 0 ? (
          <EmptyState title="No final trades" copy="The blotter remains empty until a verified QuoteMesh settlement occurs." />
        ) : (
          <table className="data-table">
            <thead><tr><th>Trade ID</th><th>RFQ</th><th>Quote</th><th>Provider</th><th>Sell</th><th>Buy</th></tr></thead>
            <tbody>
              {snapshot.recentSettlements.map((trade) => (
                <tr key={trade.tradeId}>
                  <td><Link href={`/trades/${trade.tradeId}`}>{trade.tradeId.slice(0, 14)}…</Link></td>
                  <td>#{trade.rfqId.toString()}</td><td>#{trade.quoteId.toString()}</td>
                  <td>{trade.provider.slice(0, 10)}…</td>
                  <td>{formatTokenAmount(trade.sellAmount, trade.sellToken)}</td>
                  <td>{formatTokenAmount(trade.buyAmount, trade.buyToken)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </PageShell>
  );
}
