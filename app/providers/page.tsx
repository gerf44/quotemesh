import Link from "next/link";
import { PageShell } from "@/components/page-shell";
import { EmptyState, Metric } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";

export const dynamic = "force-dynamic";

export default async function ProvidersPage() {
  const snapshot = await getMarketSnapshot();
  return (
    <PageShell
      eyebrow="Liquidity provider directory"
      title="Providers compete. Facts stay onchain."
      copy="Profiles are self-published; execution totals come from QuoteMesh events. The QuoteMesh Verified label is product-specific and is not Arc, Circle, regulatory, or KYC approval."
    >
      <section className="metrics-grid">
        <Metric label="Registered providers" value={String(snapshot.activeProviders)} />
        <Metric label="Vault liquidity" value={snapshot.liquiditySummary} />
        <Metric label="Completed trades" value={String(snapshot.settledTrades)} />
        <Metric label="Verification model" value="QuoteMesh-only" />
      </section>
      <section className="panel" style={{ marginTop: "1rem" }}>
        <div className="panel-header"><h2>Provider roster</h2><span className="mono">Event indexed</span></div>
        {snapshot.activeProviderAddresses.length ? (
          <div className="table-scroll">
            <table className="data-table">
              <thead><tr><th>Provider</th><th>Status</th></tr></thead>
              <tbody>
                {snapshot.activeProviderAddresses.map((address) => (
                  <tr key={address}>
                    <td><Link href={`/providers/${address}`}>{address}</Link></td>
                    <td><span className="status-pill positive">Active</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState title="No active providers indexed" copy="Provider addresses appear only after real registrations. Paused providers are excluded from this roster." />
        )}
      </section>
    </PageShell>
  );
}
