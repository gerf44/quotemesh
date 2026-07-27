// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { QuoteMeshTestBase } from "./QuoteMeshTestBase.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";

contract QuoteMeshFuzzTest is QuoteMeshTestBase {
    function testFuzz_SettlementConservesAssets(uint96 rawSell, uint96 rawBuy, uint32 rawDuration)
        public
    {
        uint256 sellAmount = bound(uint256(rawSell), 1e6, 1_000_000e6);
        uint256 buyAmount = bound(uint256(rawBuy), 1e6, 1_000_000e6);
        uint64 duration = uint64(bound(uint256(rawDuration), 2 minutes, 7 days));
        address[] memory none = new address[](0);

        vm.prank(taker);
        uint256 rfqId = market.createRFQ(
            address(usdc),
            address(eurc),
            sellAmount,
            buyAmount,
            uint64(block.timestamp) + duration,
            RFQMarket.AccessMode.Public,
            none,
            bytes32(0),
            ""
        );
        vm.prank(providerA);
        uint256 quoteId = market.submitQuote(
            rfqId, buyAmount, uint64(block.timestamp) + duration - 1, keccak256("fuzz")
        );
        uint256 fee = sellAmount * market.protocolFeeBps() / 10_000;
        uint256 beforeCredit = vault.availableBalanceOf(providerA, address(usdc));
        vm.prank(taker);
        market.acceptQuote(rfqId, quoteId, buyAmount);
        assertEq(
            vault.availableBalanceOf(providerA, address(usdc)) - beforeCredit + fee, sellAmount
        );
        assertTrue(vault.isSolvent(address(usdc)));
        assertTrue(vault.isSolvent(address(eurc)));
    }

    function testFuzz_ReservationNeverExceedsDeposit(uint96 rawAmount) public {
        uint256 available = vault.availableBalanceOf(providerA, address(eurc));
        uint256 amount = bound(uint256(rawAmount), 1, available);
        vm.prank(address(market));
        vault.reserve(providerA, address(eurc), amount);
        assertEq(
            vault.availableBalanceOf(providerA, address(eurc))
                + vault.reservedBalanceOf(providerA, address(eurc)),
            available
        );
    }
}
