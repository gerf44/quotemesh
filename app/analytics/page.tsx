import { AnalyticsChart } from "@/components/analytics-chart";
import { PageShell } from "@/components/page-shell";
import { EmptyState, Metric } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";

export const dynamic = "force-dynamic";

export default async function AnalyticsPage() {
  const snapshot = await getMarketSnapshot();
  const volume = Number(snapshot.usdcSellVolume);
  return (
    <PageShell
      eyebrow="Event-derived market analytics"
      title="Measure the market that actually traded."
      copy="All metrics use QuoteMesh events filtered by chain, contract address, transaction hash, and log index. Missing data stays missing."
    >
      <section className="metrics-grid">
        <Metric label="USDC sell volume" value={`${snapshot.usdcSellVolume} USDC`} />
        <Metric label="Final trades" value={String(snapshot.settledTrades)} />
        <Metric label="Open RFQs" value={String(snapshot.activeRFQs)} />
        <Metric label="Provider liquidity" value={snapshot.liquiditySummary} />
      </section>
      <section className="panel" style={{ marginTop: "1rem" }}>
        <div className="panel-header"><h2>Indexed USDC sell volume</h2><span className="mono">No FX conversion</span></div>
        {volume > 0 ? (
          <div style={{ padding: "1rem" }}><AnalyticsChart volume={volume} /></div>
        ) : (
          <EmptyState title="No chart points" copy="QuoteMesh does not invent historical rates, spreads, response times, or volume." />
        )}
      </section>
    </PageShell>
  );
}
