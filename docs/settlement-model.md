# Settlement model

The taker grants the `LiquidityVault` sell-token allowance directly or through the official
Multicall3From batch. `RFQMarket.acceptQuote` validates ownership, association, status, deadlines,
RFQ minimum, and caller-supplied stale minimum. The vault then updates liabilities and performs both
exact token transfers under one transaction. A transfer revert restores RFQ, quote, balances, fee,
and receipt state.

The protocol fee is deployment-time immutable, capped at 50 bps, rounded down, and charged only on
successful sell amounts. `provider credit + fee == sell amount`.
