import {
  encodeAbiParameters,
  encodeFunctionData,
  keccak256,
  parseAbiParameters,
  stringToHex,
  type Address,
  type Hex,
} from "viem";
import { erc20Abi, memoAbi, multicall3FromAbi, rfqMarketAbi } from "./abis";
import { ARC } from "./network";

export function buildApproveAndAcceptBatch(input: {
  sellToken: Address;
  vault: Address;
  market: Address;
  sellAmount: bigint;
  rfqId: bigint;
  quoteId: bigint;
  minimumBuyAmount: bigint;
}) {
  const calls = [
    {
      target: input.sellToken,
      allowFailure: false,
      callData: encodeFunctionData({
        abi: erc20Abi,
        functionName: "approve",
        args: [input.vault, input.sellAmount],
      }),
    },
    {
      target: input.market,
      allowFailure: false,
      callData: encodeFunctionData({
        abi: rfqMarketAbi,
        functionName: "acceptQuote",
        args: [input.rfqId, input.quoteId, input.minimumBuyAmount],
      }),
    },
  ];
  return {
    address: ARC.multicall3From,
    abi: multicall3FromAbi,
    functionName: "aggregate3" as const,
    args: [calls] as const,
  };
}

export function buildMemoAcceptance(input: {
  market: Address;
  rfqId: bigint;
  quoteId: bigint;
  minimumBuyAmount: bigint;
  actor: Address;
  clientReference: string;
}) {
  const callData = encodeFunctionData({
    abi: rfqMarketAbi,
    functionName: "acceptQuote",
    args: [input.rfqId, input.quoteId, input.minimumBuyAmount],
  });
  const memoId = keccak256(
    encodeAbiParameters(parseAbiParameters("bytes32,uint256,uint256,address,bytes32"), [
      keccak256(stringToHex("QUOTEMESH_TRADE")),
      input.rfqId,
      input.quoteId,
      input.actor,
      keccak256(stringToHex(input.clientReference || "none")),
    ]),
  );
  const memo = encodeAbiParameters(parseAbiParameters("string,uint256,uint256,string"), [
    "quotemesh/v1",
    input.rfqId,
    input.quoteId,
    input.clientReference,
  ]);
  return {
    address: ARC.memo,
    abi: memoAbi,
    functionName: "memo" as const,
    args: [input.market, callData as Hex, memoId, memo] as const,
  };
}
