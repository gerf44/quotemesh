# Architecture

`AssetRegistry` is the token/pair policy boundary. `ProviderRegistry` is identity and factual
statistics. `LiquidityVault` is the custody/accounting boundary. `RFQMarket` is the state machine
and only component allowed to reserve/release/settle. `SettlementRegistry` is append-only evidence.

Wallets and token contracts are untrusted transaction boundaries. The market/vault links are set
once. The Next.js application signs no transactions; connected wallets submit them. The current
MVP UI reads the configured contracts and their logs directly through the Arc RPC. The standalone
indexer filters project contract logs into a local cache for offline processing and is not a hosted
backend for the UI. Neither path overrides onchain state.

External Arc/Circle services are optional infrastructure. QuoteMesh settlement works without App
Kit or StableFX.
