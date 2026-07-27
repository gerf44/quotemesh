# App Kit integration status

App Kit is external Circle infrastructure. Arc Testnet Swap documents USDC/EURC support.
QuoteMesh does not currently install the App Kit SDK, request a quote, or expose a feature flag
that could imply an integration exists. The UI therefore states `not integrated`.

Before a future integration can be described as completed:

- keep an App Kit indication visually separate from firm QuoteMesh quotes;
- display timestamp, output, fees, slippage/impact, and staleness;
- never call it firm or guaranteed;
- keep Bridge/Unified Balance funding separate from RFQ settlement;
- report source and destination states and documented error recovery.

StableFX is likewise external; QuoteMesh does not request or display StableFX prices and no
undocumented API is reverse-engineered or fabricated.
