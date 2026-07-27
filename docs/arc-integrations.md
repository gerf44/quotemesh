# Arc integrations

- Network: Arc Testnet, chain ID `5042002`.
- RPC: `https://rpc.testnet.arc.network`.
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

Sources: official Arc contract address, stablecoin-native model, finality, memo, batch, gas, EVM
differences, connect, wallet, and deployment pages listed in the README.
