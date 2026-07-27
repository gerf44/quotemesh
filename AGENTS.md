# QuoteMesh repository instructions

- QuoteMesh is the product; Arc Network is infrastructure.
- Re-check current official Arc documentation before changing network values, addresses, or
  integration claims.
- Never commit secrets or fabricate deployments, quotes, volume, providers, receipts, audits, or
  endorsements.
- Keep project-deployed contracts separate from external Arc, Circle, StableFX, App Kit, Memo,
  Multicall3From, Permit2, USDC, and EURC infrastructure.
- Preserve exact vault accounting and the `actual balance >= available + reserved liabilities`
  invariant.
- Run Foundry formatting/tests plus frontend lint, typecheck, and build after material changes.
- Do not deploy or publish without an explicit user request.
