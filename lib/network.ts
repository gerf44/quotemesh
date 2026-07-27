import { arcTestnet } from "viem/chains";

export const ARC = {
  chain: arcTestnet,
  chainId: 5_042_002,
  rpcUrl: "https://rpc.testnet.arc.io",
  explorerUrl: "https://testnet.arcscan.app",
  usdc: "0x3600000000000000000000000000000000000000",
  eurc: "0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a",
  memo: "0x5294E9927c3306DcBaDb03fe70b92e01cCede505",
  multicall3From: "0x522fAf9A91c41c443c66765030741e4AaCe147D0",
  permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
  stableFxEscrow: "0x867650F5eAe8df91445971f14d89fd84F0C9a9f8",
} as const;

export const TOKENS = {
  USDC: { symbol: "USDC", address: ARC.usdc, decimals: 6 },
  EURC: { symbol: "EURC", address: ARC.eurc, decimals: 6 },
} as const;
