import Link from "next/link";
import { PageShell } from "@/components/page-shell";
import { Metric } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const snapshot = await getMarketSnapshot();
  return (
    <PageShell eyebrow="Treasury dashboard" title="One view across requests and settlement." copy="Operational entry point for takers and provider teams. Wallet ownership remains the authority for every action.">
      <section className="metrics-grid">
        <Metric label="Open RFQs" value={String(snapshot.activeRFQs)} />
        <Metric label="Settlements" value={String(snapshot.settledTrades)} />
        <Metric label="Market liquidity" value={snapshot.liquiditySummary} />
        <Metric label="RPC" value={snapshot.rpcOnline ? "Online" : "Unavailable"} />
      </section>
      <section className="section-grid">
        <div className="panel section-copy"><h2>Taker workspace</h2><p>Create exact-input requests, compare firm quotes, and use stale-output protection at acceptance.</p><Link className="button primary" href="/trade">Open terminal</Link></div>
        <div className="panel section-copy"><h2>Provider workspace</h2><p>Manage available versus reserved liquidity, quote expiries, settlement credits, and withdrawals.</p><Link className="button" href="/liquidity">Manage liquidity</Link></div>
      </section>
    </PageShell>
  );
}
