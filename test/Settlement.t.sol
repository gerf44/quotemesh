// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { QuoteMeshTestBase } from "./QuoteMeshTestBase.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";
import { SettlementRegistry } from "../contracts/SettlementRegistry.sol";
import { RestrictedTokenMock } from "./mocks/MockERC20.sol";

contract SettlementTest is QuoteMeshTestBase {
    function testAtomicSettlementAccountingFeeAndReceipt() public {
        uint256 rfqId = _createPublicRFQ();
        uint256 quoteId = _quote(rfqId, providerA, BUY_AMOUNT_A);
        uint256 takerEurcBefore = eurc.balanceOf(taker);
        uint256 providerUsdcBefore = vault.availableBalanceOf(providerA, address(usdc));

        vm.prank(taker);
        bytes32 tradeId = market.acceptQuote(rfqId, quoteId, BUY_AMOUNT_A);

        uint256 expectedFee = SELL_AMOUNT * 10 / 10_000;
        assertEq(eurc.balanceOf(taker), takerEurcBefore + BUY_AMOUNT_A);
        assertEq(
            vault.availableBalanceOf(providerA, address(usdc)),
            providerUsdcBefore + SELL_AMOUNT - expectedFee
        );
        assertEq(vault.availableBalanceOf(feeRecipient, address(usdc)), expectedFee);
        assertEq(vault.reservedBalanceOf(providerA, address(eurc)), 0);
        assertEq(settlementRegistry.getSettlement(tradeId).feeAmount, expectedFee);
        assertEq(uint256(market.getRFQ(rfqId).status), uint256(RFQMarket.RFQStatus.Filled));
        assertEq(uint256(market.getQuote(quoteId).status), uint256(RFQMarket.QuoteStatus.Filled));
        assertTrue(vault.isSolvent(address(usdc)));
        assertTrue(vault.isSolvent(address(eurc)));
    }

    function testReverseDirectionSettlementUsesCorrectAssets() public {
        address[] memory none = new address[](0);
        vm.prank(taker);
        uint256 rfqId = market.createRFQ(
            address(eurc),
            address(usdc),
            SELL_AMOUNT,
            1_050e6,
            uint64(block.timestamp + 1 hours),
            RFQMarket.AccessMode.Public,
            none,
            keccak256("reverse-rfq"),
            ""
        );
        vm.prank(providerA);
        uint256 quoteId = market.submitQuote(
            rfqId, 1_060e6, uint64(block.timestamp + 30 minutes), keccak256("reverse-quote")
        );

        uint256 takerUsdcBefore = usdc.balanceOf(taker);
        uint256 providerEurcBefore = vault.availableBalanceOf(providerA, address(eurc));
        vm.prank(taker);
        bytes32 tradeId = market.acceptQuote(rfqId, quoteId, 1_055e6);

        uint256 expectedFee = SELL_AMOUNT * 10 / 10_000;
        SettlementRegistry.SettlementReceipt memory receipt =
            settlementRegistry.getSettlement(tradeId);
        assertEq(takerUsdcBefore + 1_060e6, usdc.balanceOf(taker));
        assertEq(
            vault.availableBalanceOf(providerA, address(eurc)),
            providerEurcBefore + SELL_AMOUNT - expectedFee
        );
        assertEq(receipt.sellToken, address(eurc));
        assertEq(receipt.buyToken, address(usdc));
        assertEq(vault.reservedBalanceOf(providerA, address(usdc)), 0);
    }

    function testFeeRoundingAndCreditsExactlyConserveSellAmount() public {
        uint256 sellAmount = 1_000_001;
        address[] memory none = new address[](0);
        vm.prank(taker);
        uint256 rfqId = market.createRFQ(
            address(usdc),
            address(eurc),
            sellAmount,
            1e6,
            uint64(block.timestamp + 1 hours),
            RFQMarket.AccessMode.Public,
            none,
            bytes32(0),
            ""
        );
        vm.prank(providerA);
        uint256 quoteId = market.submitQuote(
            rfqId, 1e6, uint64(block.timestamp + 30 minutes), keccak256("rounding")
        );

        uint256 providerBefore = vault.availableBalanceOf(providerA, address(usdc));
        uint256 feeBefore = vault.availableBalanceOf(feeRecipient, address(usdc));
        vm.prank(taker);
        market.acceptQuote(rfqId, quoteId, 1e6);

        uint256 providerCredit = vault.availableBalanceOf(providerA, address(usdc)) - providerBefore;
        uint256 feeCredit = vault.availableBalanceOf(feeRecipient, address(usdc)) - feeBefore;
        assertEq(feeCredit, sellAmount * 10 / 10_000);
        assertEq(providerCredit + feeCredit, sellAmount);
    }

    function testOnlyTakerCanAcceptAndStaleMinimumReverts() public {
        uint256 rfqId = _createPublicRFQ();
        uint256 quoteId = _quote(rfqId, providerA, BUY_AMOUNT_A);
        vm.prank(outsider);
        vm.expectRevert(RFQMarket.Unauthorized.selector);
        market.acceptQuote(rfqId, quoteId, BUY_AMOUNT_A);

        vm.prank(taker);
        vm.expectRevert(RFQMarket.StaleMinimum.selector);
        market.acceptQuote(rfqId, quoteId, BUY_AMOUNT_A + 1);
        assertEq(uint256(market.getQuote(quoteId).status), uint256(RFQMarket.QuoteStatus.Active));
    }

    function testQuoteMismatchAndExpiryRevert() public {
        uint256 rfqA = _createPublicRFQ();
        uint256 rfqB = _createPublicRFQ();
        uint256 quoteA = _quote(rfqA, providerA, BUY_AMOUNT_A);
        vm.prank(taker);
        vm.expectRevert(RFQMarket.QuoteMismatch.selector);
        market.acceptQuote(rfqB, quoteA, BUY_AMOUNT_A);

        vm.warp(block.timestamp + 31 minutes);
        vm.prank(taker);
        vm.expectRevert(RFQMarket.InvalidExpiry.selector);
        market.acceptQuote(rfqA, quoteA, BUY_AMOUNT_A);
    }

    function testLosingQuoteRemainsReservedThenCanRelease() public {
        uint256 rfqId = _createPublicRFQ();
        uint256 quoteA = _quote(rfqId, providerA, BUY_AMOUNT_A);
        uint256 quoteB = _quote(rfqId, providerB, BUY_AMOUNT_B);
        vm.prank(taker);
        market.acceptQuote(rfqId, quoteB, BUY_AMOUNT_B);
        assertEq(vault.reservedBalanceOf(providerA, address(eurc)), BUY_AMOUNT_A);
        market.releaseQuote(quoteA);
        assertEq(vault.reservedBalanceOf(providerA, address(eurc)), 0);
    }

    function testCannotExecuteTwice() public {
        uint256 rfqId = _createPublicRFQ();
        uint256 quoteId = _quote(rfqId, providerA, BUY_AMOUNT_A);
        vm.prank(taker);
        market.acceptQuote(rfqId, quoteId, BUY_AMOUNT_A);
        vm.prank(taker);
        vm.expectRevert(RFQMarket.InvalidStatus.selector);
        market.acceptQuote(rfqId, quoteId, BUY_AMOUNT_A);
        assertEq(settlementRegistry.settlementCount(), 1);
    }

    function testRestrictedTransferRollsBackEntireSettlement() public {
        RestrictedTokenMock restricted = new RestrictedTokenMock();
        vm.startPrank(owner);
        assetRegistry.registerAsset(
            address(restricted), "rEUR", "test-only", keccak256("restricted")
        );
        assetRegistry.enablePair(address(usdc), address(restricted));
        vm.stopPrank();

        restricted.mint(providerA, 10_000e6);
        vm.startPrank(providerA);
        restricted.approve(address(vault), type(uint256).max);
        vault.deposit(address(restricted), 2_000e6);
        vm.stopPrank();

        address[] memory none = new address[](0);
        vm.prank(taker);
        uint256 rfqId = market.createRFQ(
            address(usdc),
            address(restricted),
            SELL_AMOUNT,
            900e6,
            uint64(block.timestamp + 1 hours),
            RFQMarket.AccessMode.Public,
            none,
            bytes32(0),
            ""
        );
        vm.prank(providerA);
        uint256 quoteId = market.submitQuote(
            rfqId, BUY_AMOUNT_A, uint64(block.timestamp + 30 minutes), keccak256("restricted")
        );
        restricted.setRestricted(taker, true);

        vm.prank(taker);
        vm.expectRevert(bytes("RESTRICTED"));
        market.acceptQuote(rfqId, quoteId, BUY_AMOUNT_A);
        assertEq(uint256(market.getRFQ(rfqId).status), uint256(RFQMarket.RFQStatus.Open));
        assertEq(uint256(market.getQuote(quoteId).status), uint256(RFQMarket.QuoteStatus.Active));
        assertEq(vault.reservedBalanceOf(providerA, address(restricted)), BUY_AMOUNT_A);
        assertEq(settlementRegistry.settlementCount(), 0);
    }
}
