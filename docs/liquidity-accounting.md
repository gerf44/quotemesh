# Liquidity accounting

Deposits credit provider `available` balances only after the vault receives the exact token amount.
Quotes move liabilities from `available` to `reserved`. Cancellation/release reverses that move.
Settlement consumes selected buy-token reservation, transfers it to the taker, receives the exact
sell token, and credits the provider minus fee plus the fee recipient.

Providers reuse credited settlement assets without withdrawing. Reserved amounts are not
withdrawable. Losing quotes are released individually. Actual token balance must always be at least
available plus reserved liabilities. Direct transfers create non-withdrawable, untouched surplus.
