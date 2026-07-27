import Link from "next/link";
import { PageShell } from "@/components/page-shell";
import { ARC } from "@/lib/network";

export default function DocsPage() {
  return (
    <PageShell
      eyebrow="Protocol quick reference"
      title="Five contracts, one atomic settlement boundary."
      copy="QuoteMesh is an independent application built on Arc Network. Arc, Circle, App Kit, StableFX, Memo, Multicall3From, Permit2, USDC, and EURC remain external infrastructure."
    >
      <section className="section-grid">
        <div className="panel section-copy">
          <h2>RFQ lifecycle</h2>
          <ol>
            <li>Taker publishes exact sell and minimum receive terms.</li>
            <li>Providers reserve buy-side inventory with each firm quote.</li>
            <li>Taker accepts one active quote with a fresh minimum output.</li>
            <li>LiquidityVault exchanges both assets atomically.</li>
            <li>SettlementRegistry stores the immutable receipt.</li>
            <li>Losing quotes are released individually without an unbounded loop.</li>
          </ol>
        </div>
        <aside className="panel section-copy">
          <h2>Official Arc Testnet configuration</h2>
          <p className="mono">Chain ID: {ARC.chainId}</p>
          <p className="mono">Wallet RPC: {ARC.walletRpcUrl}</p>
          <p className="mono">USDC: {ARC.usdc}</p>
          <p className="mono">EURC: {ARC.eurc}</p>
          <p className="mono">Memo: {ARC.memo}</p>
          <p className="mono">Multicall3From: {ARC.multicall3From}</p>
          <p>App Kit reference: not integrated</p>
        </aside>
      </section>
      <section className="panel section-copy" style={{ marginTop: "1rem" }}>
        <h2>Wallet RPC troubleshooting</h2>
        <p>
          If your wallet reports HTTP 403 for an Arc RPC ending in <code>.network</code>, open the
          wallet network settings for Arc Testnet and replace its default RPC with{" "}
          <code>{ARC.walletRpcUrl}</code>. Existing wallet network records cannot be rewritten by
          this application.
        </p>
        <Link
          href="https://docs.arc.io/arc/references/rpc-endpoints"
          className="button"
          target="_blank"
        >
          Official Arc RPC endpoints
        </Link>
      </section>
      <section className="panel section-copy" style={{ marginTop: "1rem" }}>
        <h2>Safety boundaries</h2>
        <p>
          Experimental Arc Testnet software. QuoteMesh smart contracts have not undergone a
          professional third-party security audit. Invite-only controls who may quote; it does not
          make blockchain activity private or confidential.
        </p>
        <p>
          Read the repository <code>README.md</code>, <code>SECURITY.md</code>, and{" "}
          <code>docs/</code> before testing with a wallet.
        </p>
        <Link href="https://docs.arc.io" className="button" target="_blank">Official Arc documentation</Link>
      </section>
    </PageShell>
  );
}
