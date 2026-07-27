# QuoteMesh internal final readiness review

Review date: 2026-07-27

This document records a repository-level internal code review and test run. It is not a
professional third-party security audit, an Arc or Circle approval, or a production-readiness
certification.

## Confirmed issues fixed

- Transaction feedback now distinguishes a successful receipt from a reverted transaction and an
  unavailable confirmation result. A transaction is never labelled final solely because a receipt
  call returned.
- Frontend writes require Arc Testnet, block overlapping submissions, validate IDs and six-decimal
  token amounts, and stop sequential approval flows unless the approval receipt is successful.
- RFQ creation and acceptance support both USDC-to-EURC and EURC-to-USDC directions. Token labels,
  volume, fee receipts, and balances no longer assume every amount is USDC.
- Event-derived RFQ and provider pages no longer show an unconditional empty state when active
  records exist. Closed and time-expired RFQs and paused providers are excluded.
- The event reader rejects a mismatched RPC chain, de-duplicates trade IDs, and preserves separate
  USDC and EURC quantities instead of implying an FX conversion.
- The local indexer de-duplicates persisted records and fails closed on corrupt, future, or
  deployment-inconsistent checkpoints.
- The deployment script validates the protocol fee before narrowing to `uint16` and assigns
  ownership from the actual broadcast signer.
- Tests now cover reverse-direction settlement, exact fee conservation, losing-quote release,
  cancellation/expiry release, pagination boundaries, duplicate receipts, owner fund-access
  rejection, fee-on-transfer rejection, and direct-transfer surplus handling.
- Mobile navigation is accessible, and App Kit/StableFX panels no longer imply that unavailable
  data or SDK integrations are configured.

## 1. Project-Deployed Contracts

The project maintains five contract sources:

| Contract | Purpose | Deployment status |
| --- | --- | --- |
| `AssetRegistry` | Supported assets, directional pairs, and pair limits | Not deployed |
| `ProviderRegistry` | Provider registration, status, profile hashes, and QuoteMesh-only flags | Not deployed |
| `LiquidityVault` | Available/reserved balances, settlement transfers, and fee accounting | Not deployed |
| `RFQMarket` | RFQ, quote, reservation, acceptance, and settlement lifecycle | Not deployed |
| `SettlementRegistry` | Unique immutable settlement receipts and bounded pagination | Not deployed |

No project address, deployment transaction, source-verification link, or constructor record exists.
`deployments/arc-testnet.json` intentionally records `status: pending` and an empty
`projectContracts` object.

## 2. External Arc and Circle Dependencies

The following Arc Testnet values were checked against the current official documentation and with
read-only RPC calls:

| Dependency | Address / value | Read-only result |
| --- | --- | --- |
| Chain ID | `5042002` | RPC returned `5042002` |
| USDC ERC-20 interface | `0x3600000000000000000000000000000000000000` | Code present; `decimals()` returned 6 |
| EURC | `0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a` | Code present; `decimals()` returned 6 |
| Memo | `0x5294E9927c3306DcBaDb03fe70b92e01cCede505` | Code present |
| Multicall3From | `0x522fAf9A91c41c443c66765030741e4AaCe147D0` | Code present |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | Code present |
| StableFX escrow | `0x867650F5eAe8df91445971f14d89fd84F0C9a9f8` | Code present |

These are external infrastructure and are not owned, deployed, verified, or maintained by
QuoteMesh. StableFX is not integrated into the application.

## 3. Completed Arc integrations

- Arc Testnet chain, RPC, explorer, and wrong-network handling.
- Documented USDC/EURC ERC-20 interfaces with six-decimal application accounting.
- Explicit distinction between the six-decimal USDC ERC-20 interface and the 18-decimal native gas
  representation.
- Address-filtered RPC event reconstruction for the current frontend and a separate resumable local
  indexer.
- Optional Memo acceptance call builder.
- Optional sender-preserving Multicall3From `approve + accept` builder with `allowFailure: false`.
- Direct-EOA guardrail copy for Memo and Multicall3From; Memo is not nested in Multicall3From.
- Receipt-status-aware `Pending`, `Final`, `Reverted`, and `Confirmation unavailable` states.

The builders compiled and were reviewed locally. They have not been exercised in a live Arc
transaction. Circle App Kit and StableFX pricing are not integrated.

## 4. Live onchain demo transactions

None. No wallet write, deployment, RFQ, quote, settlement, Memo transaction, or
Multicall3From transaction was broadcast during this review.

## 5. Test and build results

- Solidity formatting: passed.
- Solidity compile with Solc 0.8.30: passed.
- Foundry lint: completed with timestamp-comparison warnings in expiry logic; no lint error.
- Foundry tests: 37 passed, 0 failed, 0 skipped across 8 suites.
- Gas report: completed successfully for the same 37 tests.
- Extended fuzz tests: 1,000 runs per fuzz test, passed.
- Extended invariants: 256 runs and 16,384 calls per invariant, 0 reverts, passed.
- ESLint: passed with zero warnings.
- TypeScript `tsc --noEmit`: passed.
- Next.js production build: passed; all declared routes compiled.
- Browser QA: desktop and 390×844 mobile checked; 11 routes returned HTTP 200; browser console
  reported 0 errors and 0 warnings.
- Vercel production build and frontend deployment: completed at
  `https://quotemesh.vercel.app`.
- Production dependency audit: 0 vulnerabilities with `npm audit --omit=dev`.
- Full dependency audit: 9 high-severity findings remain in the dev-only ESLint dependency chain
  through legacy `minimatch`/`brace-expansion`. A tested ESLint 10 upgrade was incompatible with the
  current Next ESLint plugins and was reverted.
- Secret-pattern scan of project-owned sources: no embedded private key, mnemonic, entity secret,
  or API key found.

Semgrep and Slither were not installed in this environment. The review used manual source/data-flow
inspection, Foundry lint, targeted unit/fuzz/invariant tests, and frontend tooling; it must not be
described as an independent audit.

## 6. Security limitations

- No professional third-party audit or formal verification has occurred.
- Local EVM tests do not reproduce every Arc-specific runtime, token restriction, RPC, wallet,
  Memo, or Multicall3From behavior.
- Contract deployment links the vault and registries to a market exactly once. The deployer must
  verify every constructor and one-time link before broadcasting; a wrong initial link cannot be
  replaced.
- Timestamp-based expiries intentionally depend on block timestamps. Foundry reports timestamp
  comparison warnings; deadlines should include reasonable operational tolerance.
- The frontend still requires the operator/user to obtain and verify a current quote ID. It does
  not reconstruct a complete active quote ladder.
- The server-rendered frontend performs lifetime `eth_getLogs` reads. This can hit provider limits
  at scale; the included local resumable indexer is not a hosted production backend.
- Direct token transfers to the vault create surplus that is not provider credit. There is no
  administrator sweep; accidental direct transfers remain inaccessible by design.
- Fee-on-transfer tokens are rejected by observed-balance checks. Other non-standard or restricted
  token behavior can still revert an otherwise atomic settlement.
- The dev-only ESLint advisory described above remains unresolved until compatible upstream
  releases are available or the lint stack is intentionally replaced.

## 7. Deployment status

The frontend is deployed at `https://quotemesh.vercel.app`. No QuoteMesh contract has been
broadcast, verified, or configured in that frontend, so it intentionally displays the zero-state.
There is no live QuoteMesh market, liquidity, RFQ, quote, settlement, or contract-deployment
evidence.

The Vercel project was deployed successfully through the CLI, but its attempted GitHub repository
connection was rejected by the current Vercel GitHub integration permissions. Future automatic
deployments from GitHub require that integration to be authorized for `gerf44/quotemesh`.

## 8. Manual actions still required

1. Obtain an independent smart-contract and frontend security review.
2. Reconfirm every Arc network value and external address immediately before deployment.
3. Use an encrypted keystore or hardware-backed signer; never place a raw private key in the
   repository or command history.
4. Simulate the complete deployment and one-time market-link sequence, then deploy explicitly.
5. Verify all five project contract sources and record real addresses, constructor parameters,
   transaction hashes, deployment block, and explorer links.
6. Configure the deployed frontend with those verified project records and redeploy it.
7. Execute and retain evidence for live public/invite RFQs, competing quotes, cancellation/expiry
   release, both settlement directions, restricted-transfer rollback, Memo, and Multicall3From.
8. Add a hosted resumable indexer before using lifetime analytics at sustained production volume.
9. Resolve the dev-only dependency advisory when a compatible lint dependency path is available.
10. Authorize the Vercel GitHub integration for `gerf44/quotemesh` if automatic deployments are
    required.

## Brand review

- QuoteMesh has an independent name, icon, wordmark, and product identity.
- QuoteMesh branding is primary; Arc is described as infrastructure using `Built on Arc`.
- The repository does not use or modify the Arc logo.
- Copy states that QuoteMesh is not an official Arc, Circle, or StableFX product and does not imply
  partnership, certification, regulatory approval, KYC approval, audit, or endorsement.
- Provider verification is explicitly QuoteMesh-only.

## Official documentation consulted

- https://docs.arc.io/llms.txt
- https://docs.arc.io/arc/references/contract-addresses
- https://docs.arc.io/arc/references/connect-to-arc
- https://docs.arc.io/arc/references/evm-differences
- https://docs.arc.io/arc/concepts/deterministic-finality
- https://docs.arc.io/arc/concepts/transaction-memos
- https://docs.arc.io/arc/concepts/batched-transactions
- https://docs.arc.io/arc/concepts/stablecoin-native-model
- https://docs.arc.io/arc/concepts/gas-and-fees
- https://docs.arc.io/app-kit/swap
- https://docs.arc.io/stablefx
- https://www.arc.io/brand-guidelines-and-partner-toolkit
- https://community.arc.io/home/blogs/arc-brand-guidelines-and-partner-toolkit-is-live-2026-07-16
