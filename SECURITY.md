# QuoteMesh security

QuoteMesh is experimental Arc Testnet software and has not undergone a professional third-party
security audit. Do not use it with assets of real-world value.

## Protections

- supported-token and directional-pair allowlists;
- exact provider available/reserved liability accounting;
- `SafeERC20`, `ReentrancyGuard`, checks-effects-interactions, and exact balance-delta checks;
- unsupported fee-on-transfer/rebasing behavior rejected;
- full-fill atomic settlement and stale minimum-output checks;
- explicit expiries and state transitions;
- bounded invite lists and paginated reads;
- one-time market links and immutable settlement receipts;
- no proxies, `delegatecall`, arbitrary external calls, admin sweeps, or payout loops.

## Administrator boundary

The owner can configure assets/pairs and the QuoteMesh-specific verification label. Before initial
configuration, the owner also chooses the one-time market address; a malicious market would have
accounting authority, so deployment verification is mandatory. Once the intended `RFQMarket` is
linked, the owner cannot replace it, withdraw provider/taker funds, seize reservations, redirect
withdrawals, alter executed trades, or rewrite receipts.

## Assumptions and remaining risks

Official Arc USDC/EURC must retain the documented ERC-20 behavior. Restricted transfers can revert;
tests confirm settlement rolls back atomically. Timestamp deadlines tolerate normal sub-second
block timing. External RPCs, wallets, Memo, Multicall3From, App Kit, StableFX, and indexers have
their own risks. Unexpected direct token transfers remain untouched surplus.

## Reporting

Do not include private keys, seed phrases, wallet credentials, or sensitive user data in a report.
Provide a minimal reproducible test and affected commit to the repository owner through a private
channel before public disclosure.
