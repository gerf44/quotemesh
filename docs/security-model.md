# Security model

See `SECURITY.md`. Core assumptions are allowlisted standard tokens, exact balance deltas, immutable
dependencies, bounded data, and pull withdrawals. Administrators manage configuration but cannot
touch funds. Providers risk reservations remaining locked until a releasable condition; anyone can
release after expiry/fill/cancellation. Takers risk stale prices and protect themselves with RFQ and
acceptance minimums.

External wallets, RPCs, Arc transaction extensions, App Kit, and StableFX are independent trust
boundaries. QuoteMesh is unaudited Testnet software. Before the one-time market links are set, the
deployment owner controls which market contract receives accounting authority; deployment review
must confirm all three registries/vault point to the intended immutable `RFQMarket`.
