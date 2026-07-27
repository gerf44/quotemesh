import Link from "next/link";
import { ArrowRight, Landmark, Scale, ShieldCheck } from "lucide-react";
import { Metric, EmptyState, StatusPill } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";
import { ARC } from "@/lib/network";
import { formatTokenAmount } from "@/lib/token-display";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const snapshot = await getMarketSnapshot();
  return (
    <main>
      <section className="page-shell">
        <div className="page-intro">
          <div>
            <p className="eyebrow">Independent stablecoin RFQ marketplace · Built on Arc</p>
            <h1>Firm quotes. Reserved liquidity. Atomic settlement.</h1>
            <p>
              QuoteMesh lets treasury teams request USDC/EURC prices from competing providers,
              compare executable terms, and settle the selected quote through transparent
              project-owned contracts.
            </p>
          </div>
          <div className="stack">
            <Link href="/trade" className="button primary">
              Request a quote <ArrowRight size={17} />
            </Link>
            <Link href="/liquidity" className="button">
              Become a provider
            </Link>
          </div>
        </div>

        {snapshot.warning && <p className="notice">{snapshot.warning}</p>}

        <section className="metrics-grid" style={{ marginTop: "1rem" }}>
          <Metric label="USDC sell volume" value={`${snapshot.usdcSellVolume} USDC`} note="No EURC/USD conversion assumed" />
          <Metric label="Provider liquidity" value={snapshot.liquiditySummary} note="Assets shown separately" />
          <Metric label="Open RFQs" value={String(snapshot.activeRFQs)} note="Current indexed state" />
          <Metric label="Active providers" value={String(snapshot.activeProviders)} note="Self-registered onchain" />
        </section>

        <section className="section-grid">
          <div className="panel">
            <div className="panel-header">
              <h2>Recent final settlements</h2>
              <StatusPill tone={snapshot.rpcOnline ? "positive" : "warning"}>
                {snapshot.rpcOnline ? `Arc block ${snapshot.indexedTo}` : "Awaiting deployment"}
              </StatusPill>
            </div>
            {snapshot.recentSettlements.length === 0 ? (
              <EmptyState
                title="No settlements indexed"
                copy="QuoteMesh does not fabricate live volume. Final trades will appear here from RFQMarket events after a verified deployment."
                action={<Link className="button ghost" href="/trades">Open blotter</Link>}
              />
            ) : (
              <table className="data-table">
                <thead>
                  <tr><th>Trade</th><th>RFQ</th><th>Provider</th><th>Sell</th><th>Receive</th></tr>
                </thead>
                <tbody>
                  {snapshot.recentSettlements.map((trade) => (
                    <tr key={trade.tradeId}>
                      <td><Link href={`/trades/${trade.tradeId}`}>{trade.tradeId.slice(0, 10)}…</Link></td>
                      <td>#{trade.rfqId.toString()}</td>
                      <td>{trade.provider.slice(0, 8)}…</td>
                      <td>{formatTokenAmount(trade.sellAmount, trade.sellToken)}</td>
                      <td>{formatTokenAmount(trade.buyAmount, trade.buyToken)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
          <aside className="panel section-copy">
            <p className="eyebrow">Execution on Arc</p>
            <h2>One committed transaction, one final state.</h2>
            <p>
              The provider&apos;s buy-side asset is reserved when a firm quote is posted.
              Acceptance pulls the RFQ sell asset, delivers the buy asset, credits the provider,
              accounts for the disclosed fee, and records the receipt atomically.
            </p>
            <p className="mono">{ARC.chain.name} · Chain {ARC.chainId} · Gas in USDC</p>
          </aside>
        </section>

        <section className="steps" style={{ marginTop: "1rem" }}>
          <article><Landmark size={22} /><h3>Fund inventory</h3><p>Providers deposit the documented Arc Testnet USDC or EURC interfaces. Available and reserved liabilities stay separate.</p></article>
          <article><Scale size={22} /><h3>Compete on price</h3><p>Public or invite-only RFQs collect multiple full-fill firm quotes with explicit expiries.</p></article>
          <article><ShieldCheck size={22} /><h3>Reserve before quoting</h3><p>No provider can quote buy-side inventory that is not already available inside the vault.</p></article>
          <article><ArrowRight size={22} /><h3>Settle and reconcile</h3><p>Arc finality closes the trade and an immutable onchain receipt supports downstream accounting.</p></article>
        </section>
      </section>
    </main>
  );
}
