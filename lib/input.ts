import { parseUnits } from "viem";

export function isPositiveTokenAmount(value: string, decimals = 6): boolean {
  if (!new RegExp(`^(?:0|[1-9]\\d*)(?:\\.\\d{1,${decimals}})?$`).test(value)) return false;
  try {
    return parseUnits(value, decimals) > 0n;
  } catch {
    return false;
  }
}

export function isPositiveInteger(value: string): boolean {
  return /^[1-9]\d*$/.test(value);
}
