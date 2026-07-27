import { ExecutionForm } from "@/components/execution-form";
import { PageShell } from "@/components/page-shell";
import { EmptyState, StatusPill } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";
import { formatTokenAmount } from "@/lib/token-display";

export default async function RFQDetailPage({ params }: { params: Promise<{ rfqId: string }> }) {
  const { rfqId } = await params;
  const snapshot = await getMarketSnapshot();
  const rfq = snapshot.openRFQs.find((item) => item.rfqId.toString() === rfqId);
  return (
    <PageShell
      eyebrow="RFQ detail"
      title={`Request #${rfqId}`}
      copy="Taker terms, invited providers, competing firm quotes, and final transaction timeline are derived from the configured Arc contracts."
      actions={
        <StatusPill tone={rfq ? "positive" : "warning"}>
          {rfq ? "Open onchain RFQ" : "Not in open queue"}
        </StatusPill>
      }
    >
      <section className="section-grid">
        <div className="panel">
          <div className="panel-header"><h2>RFQ terms</h2><span className="mono">RFQ #{rfqId}</span></div>
          {rfq ? (
            <div>
              <p className="mono">Taker: {rfq.taker}</p>
              <p>Sell: <strong>{formatTokenAmount(rfq.sellAmount, rfq.sellToken)}</strong></p>
              <p>Minimum receive: <strong>{formatTokenAmount(rfq.minBuyAmount, rfq.buyToken)}</strong></p>
              <p>Access: <strong>{rfq.accessMode === 0 ? "Public" : "Invite-only"}</strong></p>
              <p className="mono">Expires: {new Date(Number(rfq.expiresAt) * 1_000).toISOString()}</p>
              <div className="notice">
                The current UI does not reconstruct the quote ladder. Verify the quote ID and
                current quote state from the contract before acceptance.
              </div>
            </div>
          ) : (
            <EmptyState title="Open RFQ data unavailable" copy="The request is not in the current open event-derived queue. It may be unknown, expired, cancelled, or settled." />
          )}
        </div>
        <aside className="panel">
          <div className="panel-header"><h2>Role-aware actions</h2><span className="mono">Contract-enforced</span></div>
          <ExecutionForm initialRfqId={rfqId} />
        </aside>
      </section>
    </PageShell>
  );
}
