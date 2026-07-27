import Link from "next/link";
import { PageShell } from "@/components/page-shell";
import { EmptyState, Metric } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";
import { formatTokenAmount } from "@/lib/token-display";

export const dynamic = "force-dynamic";

export default async function RFQsPage() {
  const snapshot = await getMarketSnapshot();
  return (
    <PageShell
      eyebrow="Market discovery"
      title="Live request book"
      copy="Public and invite-only requests reconstructed from QuoteMesh contract events."
      actions={<Link href="/trade" className="button primary">Create RFQ</Link>}
    >
      <section className="metrics-grid">
        <Metric label="Open RFQs" value={String(snapshot.activeRFQs)} />
        <Metric label="Providers" value={String(snapshot.activeProviders)} />
        <Metric label="Settled trades" value={String(snapshot.settledTrades)} />
        <Metric label="Indexed block" value={snapshot.indexedTo?.toString() || "—"} />
      </section>
      <section className="panel" style={{ marginTop: "1rem" }}>
        <div className="panel-header"><h2>RFQ queue</h2><span className="mono">Onchain source of truth</span></div>
        {snapshot.openRFQs.length ? (
          <div className="table-scroll">
            <table className="data-table">
              <thead>
                <tr><th>RFQ</th><th>Sell</th><th>Minimum receive</th><th>Access</th><th>Expires</th></tr>
              </thead>
              <tbody>
                {snapshot.openRFQs.map((rfq) => (
                  <tr key={rfq.rfqId.toString()}>
                    <td><Link href={`/rfqs/${rfq.rfqId.toString()}`}>#{rfq.rfqId.toString()}</Link></td>
                    <td>{formatTokenAmount(rfq.sellAmount, rfq.sellToken)}</td>
                    <td>{formatTokenAmount(rfq.minBuyAmount, rfq.buyToken)}</td>
                    <td>{rfq.accessMode === 0 ? "Public" : "Invite-only"}</td>
                    <td>{new Date(Number(rfq.expiresAt) * 1_000).toISOString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title="No open RFQs found"
            copy="Create the first RFQ after deployment. Cancelled, expired, or filled requests are excluded from the open queue."
            action={<Link href="/trade" className="button">Open terminal</Link>}
          />
        )}
      </section>
    </PageShell>
  );
}
