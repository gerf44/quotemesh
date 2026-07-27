# Event indexing

`indexer/index.ts` scans only configured QuoteMesh contract addresses in bounded block ranges.
State is saved atomically to `indexer/data/events.json` with the last indexed block. RPC calls retry,
and `npm run index:reset` replays from the deployment block.

The deterministic ID is:

```text
chainId:transactionHash:logIndex:contractAddress
```

The cache is intended for offline search and analytics; the current MVP UI does not consume it.
Contract reads remain authoritative for RFQ/quote validity, liquidity, ownership, and settlement.
Arc's dual USDC event model requires emitter-aware deduplication before adding token-transfer
analytics.
