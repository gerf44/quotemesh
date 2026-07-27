import Link from "next/link";
import { Brand } from "./brand";
import { WalletButton } from "./wallet-button";

const links = [
  ["/trade", "Trade"],
  ["/rfqs", "RFQs"],
  ["/providers", "Providers"],
  ["/liquidity", "Liquidity"],
  ["/trades", "Trades"],
  ["/analytics", "Analytics"],
  ["/docs", "Docs"],
] as const;

export function SiteHeader() {
  return (
    <header className="site-header">
      <Brand />
      <nav aria-label="Primary navigation">
        {links.map(([href, label]) => (
          <Link key={href} href={href}>
            {label}
          </Link>
        ))}
      </nav>
      <WalletButton />
    </header>
  );
}
