// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { QuoteMeshTestBase } from "./QuoteMeshTestBase.sol";
import { SettlementRegistry } from "../contracts/SettlementRegistry.sol";

contract SettlementRegistryTest is QuoteMeshTestBase {
    function testOnlyMarketWritesAndMarketConfiguredOnce() public {
        SettlementRegistry.SettlementReceipt memory receipt = SettlementRegistry.SettlementReceipt({
            tradeId: keccak256("trade"),
            rfqId: 1,
            quoteId: 1,
            taker: taker,
            provider: providerA,
            sellToken: address(usdc),
            buyToken: address(eurc),
            sellAmount: 1e6,
            buyAmount: 1e6,
            feeAmount: 0,
            settledAt: uint64(block.timestamp)
        });
        vm.prank(outsider);
        vm.expectRevert(SettlementRegistry.UnauthorizedMarket.selector);
        settlementRegistry.recordSettlement(receipt);

        vm.prank(owner);
        vm.expectRevert(SettlementRegistry.MarketAlreadySet.selector);
        settlementRegistry.setMarketOnce(address(market));
    }

    function testReceiptPaginationAndIndexes() public {
        uint256 rfqId = _createPublicRFQ();
        uint256 quoteId = _quote(rfqId, providerA, BUY_AMOUNT_A);
        vm.prank(taker);
        bytes32 tradeId = market.acceptQuote(rfqId, quoteId, BUY_AMOUNT_A);
        assertEq(settlementRegistry.settlementCount(), 1);
        assertEq(settlementRegistry.settlementAt(0).tradeId, tradeId);
        assertEq(settlementRegistry.getSettlements(0, 10)[0].tradeId, tradeId);
        assertEq(settlementRegistry.getSettlementsByTaker(taker, 0, 10)[0].tradeId, tradeId);
        assertEq(settlementRegistry.getSettlementsByProvider(providerA, 0, 10)[0].tradeId, tradeId);
        assertEq(settlementRegistry.getSettlements(1, 10).length, 0);

        vm.expectRevert(SettlementRegistry.InvalidPagination.selector);
        settlementRegistry.getSettlements(0, 0);
        vm.expectRevert(SettlementRegistry.InvalidPagination.selector);
        settlementRegistry.getSettlements(2, 1);

        SettlementRegistry.SettlementReceipt memory duplicate =
            settlementRegistry.getSettlement(tradeId);
        vm.prank(address(market));
        vm.expectRevert(SettlementRegistry.DuplicateSettlement.selector);
        settlementRegistry.recordSettlement(duplicate);
    }
}
