# Arc Testnet deployment

Deployment has not been executed.

1. Re-check the current Arc documentation and contract addresses.
2. Run all contract/frontend checks.
3. Import an encrypted Foundry keystore:
   `.\.tools\foundry\cast.exe wallet import quotemesh-deployer --interactive`.
4. Fund it with Arc Testnet USDC/EURC from the Circle Faucet.
5. Set `ARC_RPC_URL`, `FEE_RECIPIENT`, and `PROTOCOL_FEE_BPS`.
6. Run `.\scripts\deploy-arc-testnet.ps1 -Account quotemesh-deployer`.
7. Extract real addresses and transaction hashes from `broadcast/`.
8. Verify source with `scripts/verify-arc-testnet.ps1` and the Blockscout endpoint.
9. Independently query bytecode, owner, one-time links, assets, pairs, fee, and chain ID.
10. Update `deployments/arc-testnet.json` only with verified facts.

Order: AssetRegistry, ProviderRegistry, SettlementRegistry, LiquidityVault, RFQMarket, one-time
links, official USDC/EURC registration, directional pair enablement. Constructor arguments and all
verification links must be recorded.
