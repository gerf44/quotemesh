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

| Contract | Purpose | Arc Testnet address | Source status |
| --- | --- | --- | --- |
| `AssetRegistry` | Supported assets, directional pairs, and pair limits | `0x32906f2105bC66F9508091c4cAfe4cD0D7F95394` | ArcScan verified |
| `ProviderRegistry` | Provider registration, status, profile hashes, and QuoteMesh-only flags | `0x2Ea027838Acf30B1be649cb0738e982ad5709859` | ArcScan verified |
| `LiquidityVault` | Available/reserved balances, settlement transfers, and fee accounting | `0xfeAe059ECd0248C917A80a079F67fDe53B7a3fe5` | ArcScan verified |
| `RFQMarket` | RFQ, quote, reservation, acceptance, and settlement lifecycle | `0xe9633B9D35a786A5cE2ebCF3e28D5f78dDDbA3c9` | ArcScan verified |
| `SettlementRegistry` | Unique immutable settlement receipts and bounded pagination | `0x14D7Ac9BD50f66D93c21c82BB61F9bE7f72C51be` | ArcScan verified |

All five contracts were deployed in Arc Testnet block `53965111`. All 14 deployment and
initialization receipts succeeded. Bytecode, owners, one-time market links, both directional
pairs, pair limits, fee recipient, and the zero-bps protocol fee were independently queried.
Constructor parameters, transaction hashes, and verified source links are recorded in
`deployments/arc-testnet.json` and `docs/deployment.md`.

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

The direct EOA RFQ lifecycle was exercised in live Arc transactions. The optional Memo and
Multicall3From acceptance builders compiled and were reviewed locally but have not been used in a
live transaction. Circle App Kit and StableFX pricing are not integrated.

## 4. Live onchain demo transactions

One self-controlled lifecycle was completed with the same wallet as taker and provider. This
tests integration behavior but is not independent counterparty activity or proof of market
liquidity.

| Action | Transaction |
| --- | --- |
| Register provider | `0x5d94139f82c19698d1f469b4ba62909083b63158d4712fb29bbb5ed71d74aec3` |
| Approve and deposit 2 USDC | `0xe1337266d719f1e37522c498de0279df350b295b638ccda0f5f8b9d27c30bc40`, `0x108239d2dd166bb3840921922e1e8d1d7c17c92d0357d4d7837e07ebcc45d387` |
| Create EURC-to-USDC RFQ #1 | `0x2e0134a5995524bb8810c5b3fb0f8e0b9b7915de2eacb74b437e4aa5d7e46de1` |
| Submit firm quote #1 | `0x02130ae173bf60166801040b02d0229ec45cdf4012d0c6793640cb2cfb78e547` |
| Approve 1 EURC and accept quote | `0xfc9882f017b7f1157bdc0b4a536fd303be933ec65dd3603c52c26db29b4d4879`, `0x9c5a20a2395acb1ce6595583ce2184e21794021b689d6a0cad3dbc824015f9a6` |

All seven receipts succeeded. Settlement count is `1`; trade ID is
`0x008b6e0c0d8c578cfb43300818ca3749ea55faef078025291ea5fd1963fe1fcc`.
RFQ status is Filled, quote status is Filled, active reservation is zero, and the receipt records
exactly 1 EURC sold for 1 USDC with a zero fee. Post-settlement USDC and EURC vault balances each
equal their 1-token liabilities, and both solvency checks returned true.

No live Memo, Multicall3From, invite-only, competing-quote, cancellation/expiry release, or
restricted-transfer transaction has been broadcast.

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
- The full 37-test Foundry suite and the complete lint/typecheck/production-build pipeline were run
  again after deployment preparation and passed.
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

The frontend was production-redeployed and aliased at `https://quotemesh.vercel.app`. The Vercel
build passed with the five verified contract addresses and deployment block configured as
production environment variables. The five project contracts are deployed and source-verified on
Arc Testnet.

The Vercel project was deployed successfully through the CLI, but its attempted GitHub repository
connection was rejected by the current Vercel GitHub integration permissions. Future automatic
deployments from GitHub require that integration to be authorized for `gerf44/quotemesh`.

## 8. Manual actions still required

1. Obtain an independent smart-contract and frontend security review.
2. Use separate taker/provider wallets for independent live public and invite-only RFQs,
   competing quotes, cancellation/expiry release, and both settlement directions.
3. Execute and retain live evidence for restricted-transfer rollback, Memo, and Multicall3From.
4. Add a hosted resumable indexer before using lifetime analytics at sustained production volume.
5. Resolve the dev-only dependency advisory when a compatible lint dependency path is available.
6. Authorize the Vercel GitHub integration for `gerf44/quotemesh` if automatic deployments are
   required.
7. Replace the single EOA owner with an operationally appropriate multisig or governance process
   before any real-value use.

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
