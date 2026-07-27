import { PageShell } from "@/components/page-shell";
import { ProviderConsole } from "@/components/provider-console";
import { EmptyState, Metric } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";

export const dynamic = "force-dynamic";

export default async function LiquidityPage() {
  const snapshot = await getMarketSnapshot();
  return (
    <PageShell
      eyebrow="Provider workspace"
      title="Inventory, reservations, withdrawals."
      copy="Deposit supported stablecoins, submit firm prices, and reuse received settlement assets. Reserved balances are never withdrawable."
    >
      <section className="metrics-grid">
        <Metric label="Vault assets" value={snapshot.liquiditySummary} note="No cross-currency sum" />
        <Metric label="Reserved" value="—" note="Connect a provider wallet" />
        <Metric label="Available" value="—" note="Connect a provider wallet" />
        <Metric label="Network" value="Arc Testnet" note="Gas paid in USDC" />
      </section>
      <section className="section-grid">
        <div className="panel">
          <div className="panel-header"><h2>Provider action console</h2><span className="mono">Pull-based custody</span></div>
          <ProviderConsole />
        </div>
        <aside className="panel">
          <div className="panel-header"><h2>Active inventory</h2><span className="mono">Available ≠ reserved</span></div>
          <EmptyState title="Connect provider wallet" copy="Balances and active quotes will be read directly from LiquidityVault and RFQMarket." />
        </aside>
      </section>
    </PageShell>
  );
}
