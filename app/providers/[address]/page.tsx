import { notFound } from "next/navigation";
import { getAddress, isAddress } from "viem";
import { PageShell } from "@/components/page-shell";
import { EmptyState, Metric } from "@/components/ui";
import { getMarketSnapshot } from "@/lib/market-data";

export default async function ProviderPage({ params }: { params: Promise<{ address: string }> }) {
  const { address } = await params;
  if (!isAddress(address)) notFound();
  const provider = getAddress(address);
  const snapshot = await getMarketSnapshot();
  const active = snapshot.activeProviderAddresses.some(
    (candidate) => candidate.toLowerCase() === provider.toLowerCase(),
  );
  return (
    <PageShell
      eyebrow="Provider profile"
      title={`${provider.slice(0, 10)}…${provider.slice(-8)}`}
      copy="Public profile metadata and factual QuoteMesh execution statistics."
    >
      <section className="metrics-grid">
        <Metric label="Trades completed" value="—" />
        <Metric label="Quotes submitted" value="—" />
        <Metric label="Quote-to-fill" value="—" />
        <Metric label="Provider status" value={active ? "Active" : "Not active"} />
      </section>
      <section className="panel" style={{ marginTop: "1rem" }}>
        <EmptyState
          title="Profile statistics not indexed"
          copy={active
            ? "This address is active in ProviderRegistry. Profile metadata and per-provider quote statistics are not rendered by the current event reader."
            : "No active ProviderRegistry state was found for this address on the configured deployment."}
        />
      </section>
    </PageShell>
  );
}
