# Arc Testnet deployment records

`arc-testnet.json` is intentionally marked `pending` until a real broadcast is completed.
After deployment, record only addresses and transaction hashes taken from the Foundry
broadcast artifact and verify each address through the Arc RPC and ArcScan.

Use an encrypted Foundry keystore:

```powershell
cast wallet import quotemesh-deployer --interactive
.\scripts\deploy-arc-testnet.ps1 -Account quotemesh-deployer
```

Never pass a private key on the command line and never commit `.env`.
