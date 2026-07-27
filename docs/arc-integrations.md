# Arc integrations

- Network: Arc Testnet, chain ID `5042002`.
- Frontend RPC: `https://rpc.blockdaemon.testnet.arc.io`.
- Wallet RPCs: Blockdaemon, dRPC, then QuickNode, all from the official Arc RPC endpoint list.
- Official primary RPC: `https://rpc.testnet.arc.io`; it returned HTTP 403 from the deployment
  environment during the 2026-07-27 readiness check, so it is not in the wallet RPC list.
- Explorer: `https://testnet.arcscan.app`.
- USDC ERC-20 interface: `0x3600000000000000000000000000000000000000`, 6 decimals.
- EURC: `0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a`, 6 decimals.
- Native USDC gas accounting: 18 decimals; application transfers use the 6-decimal interface.
- Memo: `0x5294E9927c3306DcBaDb03fe70b92e01cCede505`, direct EOA only.
- Multicall3From: `0x522fAf9A91c41c443c66765030741e4AaCe147D0`, direct EOA only;
  QuoteMesh sets `allowFailure: false` for approval and acceptance.
- Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`.
- StableFX FxEscrow: external reference only, not called by QuoteMesh.

Finality UX is wallet confirmation, pending/unconfirmed, then final only after a successful Arc
receipt. Reverted and confirmation-unavailable states are distinct. Memo and Multicall3From
preserve the original EOA through Arc's CallFrom behavior; they are never nested. Memo content must
not include personal, confidential, or compliance-sensitive information.

Some wallet and library presets still contain an older `.network` Arc RPC domain. QuoteMesh
overrides that preset for new wallet network additions. A wallet that already saved the old
endpoint must be updated in its network settings; the transaction UI detects the resulting
HTTP 403 and shows the current RPC plus a copy action.

On connection, the frontend automatically requests Arc Testnet when the wallet reports a different
chain ID. The request is attempted once per wrong-network transition to avoid repeated prompts
after a rejection. The header retains a manual retry button, and transactions remain disabled
until the wallet reports chain ID `5042002`.

Sources: official Arc contract address, stablecoin-native model, finality, memo, batch, gas, EVM
differences, connect, wallet, RPC endpoint, and deployment pages listed in the README.
