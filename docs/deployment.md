# Arc Testnet deployment

QuoteMesh was deployed to Arc Testnet on 2026-07-27 in block `53965111` by
`0x8600D14106aBeaBd7Ef96e82D03C0a3a73bB0AEB`. All 14 deployment and one-time
configuration receipts succeeded. The five project contract sources were verified through
ArcScan/Blockscout and independently returned source code through the ArcScan API.

Network: Arc Testnet (`5042002`). Protocol fee: `0` bps. Owner and fee recipient:
`0x8600D14106aBeaBd7Ef96e82D03C0a3a73bB0AEB`.

## Project-Deployed Contracts

| Contract | Address | Deployment transaction | Verified source |
| --- | --- | --- | --- |
| AssetRegistry | `0x32906f2105bC66F9508091c4cAfe4cD0D7F95394` | [transaction](https://testnet.arcscan.app/tx/0xe1ce6727a91a3af5ecc61df0a89bc67647d86e61f6014d3cc2661d8993a9b462) | [ArcScan](https://testnet.arcscan.app/address/0x32906f2105bc66f9508091c4cafe4cd0d7f95394?tab=contract) |
| ProviderRegistry | `0x2Ea027838Acf30B1be649cb0738e982ad5709859` | [transaction](https://testnet.arcscan.app/tx/0x6225d61fb0de6c3eca7f382bf3a040b7f2facc59dbd0c312ba7df65f5cba8776) | [ArcScan](https://testnet.arcscan.app/address/0x2ea027838acf30b1be649cb0738e982ad5709859?tab=contract) |
| SettlementRegistry | `0x14D7Ac9BD50f66D93c21c82BB61F9bE7f72C51be` | [transaction](https://testnet.arcscan.app/tx/0x8a891f041dafa749611f361da11fada9ac15c7f11748c53860a0b7b4b458e71f) | [ArcScan](https://testnet.arcscan.app/address/0x14d7ac9bd50f66d93c21c82bb61f9be7f72c51be?tab=contract) |
| LiquidityVault | `0xfeAe059ECd0248C917A80a079F67fDe53B7a3fe5` | [transaction](https://testnet.arcscan.app/tx/0x28cc25c322a317de49b8d0c5cf2e671f3eb77cd72882a020bc6e4b7dd386591f) | [ArcScan](https://testnet.arcscan.app/address/0xfeae059ecd0248c917a80a079f67fde53b7a3fe5?tab=contract) |
| RFQMarket | `0xe9633B9D35a786A5cE2ebCF3e28D5f78dDDbA3c9` | [transaction](https://testnet.arcscan.app/tx/0xf35b087fadf19d21132504f9cfe6c575ed0a6daa66bd9bdcba02e5db91987b36) | [ArcScan](https://testnet.arcscan.app/address/0xe9633b9d35a786a5ce2ebcf3e28d5f78dddba3c9?tab=contract) |

Constructor parameters, all nine initialization transaction hashes, and the verified external
addresses are recorded in `deployments/arc-testnet.json`. ProviderRegistry, SettlementRegistry,
and LiquidityVault each have their one-time `market` link set to the RFQMarket address.

## Live interaction evidence

One self-controlled lifecycle was completed in blocks `53967911` through `53968005`. The same
wallet acted as taker and provider, so the result proves the integration path but does not prove
independent counterparties or market activity.

| Action | Transaction |
| --- | --- |
| Register provider | [ArcScan](https://testnet.arcscan.app/tx/0x5d94139f82c19698d1f469b4ba62909083b63158d4712fb29bbb5ed71d74aec3) |
| Approve USDC | [ArcScan](https://testnet.arcscan.app/tx/0xe1337266d719f1e37522c498de0279df350b295b638ccda0f5f8b9d27c30bc40) |
| Deposit 2 USDC | [ArcScan](https://testnet.arcscan.app/tx/0x108239d2dd166bb3840921922e1e8d1d7c17c92d0357d4d7837e07ebcc45d387) |
| Create RFQ #1 | [ArcScan](https://testnet.arcscan.app/tx/0x2e0134a5995524bb8810c5b3fb0f8e0b9b7915de2eacb74b437e4aa5d7e46de1) |
| Submit quote #1 | [ArcScan](https://testnet.arcscan.app/tx/0x02130ae173bf60166801040b02d0229ec45cdf4012d0c6793640cb2cfb78e547) |
| Approve EURC | [ArcScan](https://testnet.arcscan.app/tx/0xfc9882f017b7f1157bdc0b4a536fd303be933ec65dd3603c52c26db29b4d4879) |
| Accept and settle | [ArcScan](https://testnet.arcscan.app/tx/0x9c5a20a2395acb1ce6595583ce2184e21794021b689d6a0cad3dbc824015f9a6) |

The resulting receipt has trade ID
`0x008b6e0c0d8c578cfb43300818ca3749ea55faef078025291ea5fd1963fe1fcc`.
Independent reads confirmed a Filled RFQ and quote, one unique settlement, zero reserved
liquidity, exact 1-token USDC and EURC liabilities matched by actual vault balances, and solvency
for both tokens.

## External Arc and Circle Dependencies

QuoteMesh did not deploy or own these contracts:

- USDC ERC-20 interface: `0x3600000000000000000000000000000000000000`
- EURC: `0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a`
- Memo: `0x5294E9927c3306DcBaDb03fe70b92e01cCede505`
- Multicall3From: `0x522fAf9A91c41c443c66765030741e4AaCe147D0`
- Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3`
- StableFX escrow: `0x867650F5eAe8df91445971f14d89fd84F0C9a9f8` (not integrated)

## Reproducible operations

- Deploy using an encrypted Foundry account:
  `.\scripts\deploy-arc-testnet.ps1 -Account <account-name>`
- Verify one contract:
  `.\scripts\verify-arc-testnet.ps1 -Address <address> -Contract <path:name> -ConstructorArgs <abi-encoded-args>`
- Run the documented self-controlled lifecycle through direct Arc RPC submissions (this avoids
  unsupported local emulation of Arc's transfer-restriction precompile):
  `.\scripts\run-live-lifecycle.ps1 -Account <account-name> -ExpectedAddress <address>`

Never pass a private key on the command line or store it in `.env`. A deployment must be simulated,
broadcast, checked onchain, verified in the explorer, and recorded with its real evidence before it
is described as deployed.
