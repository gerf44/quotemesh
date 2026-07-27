import { formatUnits, getAddress, isAddress, type Address } from "viem";
import { TOKENS } from "./network";

type KnownToken = (typeof TOKENS)[keyof typeof TOKENS];

export function knownToken(address: Address | string): KnownToken | null {
  if (!isAddress(address)) return null;
  const normalized = getAddress(address);
  return (
    Object.values(TOKENS).find((token) => getAddress(token.address) === normalized) ?? null
  );
}

export function tokenSymbol(address: Address | string): string {
  const token = knownToken(address);
  return token ? token.symbol : `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function formatTokenAmount(amount: bigint, address: Address | string): string {
  const token = knownToken(address);
  if (!token) return `${amount.toString()} base units ${tokenSymbol(address)}`;
  return `${formatUnits(amount, token.decimals)} ${token.symbol}`;
}
