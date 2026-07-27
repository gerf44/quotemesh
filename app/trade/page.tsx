import { CreateRFQForm } from "@/components/create-rfq-form";
import { ExecutionForm } from "@/components/execution-form";
import { PageShell } from "@/components/page-shell";
import { EmptyState, StatusPill } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";

export const dynamic = "force-dynamic";

export default async function TradePage() {
  const snapshot = await getMarketSnapshot();
  return (
    <PageShell
      eyebrow="USDC / EURC · Professional RFQ terminal"
      title="Request, compare, execute."
      copy="Create an exact-input RFQ, collect reserved firm quotes, then settle the selected provider atomically on Arc."
      actions={<StatusPill tone={snapshot.rpcOnline ? "positive" : "warning"}>{snapshot.rpcOnline ? "Arc online" : "Not deployed"}</StatusPill>}
    >
      <section className="terminal-grid">
        <div className="panel">
          <div className="panel-header"><h2>RFQ ticket</h2><span className="mono">Taker</span></div>
          <CreateRFQForm />
        </div>
        <div className="panel">
          <div className="panel-header">
            <h2>Firm quote ladder</h2>
            <span className="mono">Best receive first</span>
          </div>
          <EmptyState
            title="Quote ladder not loaded"
            copy="The current aggregate terminal does not reconstruct active quote state. Enter only an RFQ and quote ID verified against RFQMarket; provider rates and reference differences are never synthesized."
          />
          <div className="notice">
            App Kit indicative reference: <strong>not integrated</strong>. QuoteMesh does not show
            an App Kit price until a real SDK response, timestamp, fees, and slippage data are
            implemented and validated.
          </div>
        </div>
        <div className="panel">
          <div className="panel-header"><h2>Execution control</h2><span className="mono">Pending → Final</span></div>
          <ExecutionForm />
        </div>
      </section>
    </PageShell>
  );
}
