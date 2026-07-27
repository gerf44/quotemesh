// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { QuoteMeshTestBase } from "./QuoteMeshTestBase.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";
import { LiquidityVault } from "../contracts/LiquidityVault.sol";

contract RFQMarketTest is QuoteMeshTestBase {
    function testCreatesPublicAndInviteOnlyRFQs() public {
        uint256 publicId = _createPublicRFQ();
        uint256 inviteId = _createInviteRFQ(providerA);
        assertEq(uint256(market.getRFQ(publicId).accessMode), 0);
        assertEq(uint256(market.getRFQ(inviteId).accessMode), 1);
        assertEq(market.getInvitedProviders(inviteId)[0], providerA);
    }

    function testRejectsDuplicateInviteAndNonInvitedProvider() public {
        address[] memory invites = new address[](2);
        invites[0] = providerA;
        invites[1] = providerA;
        vm.prank(taker);
        vm.expectRevert(RFQMarket.InvalidInvites.selector);
        market.createRFQ(
            address(usdc),
            address(eurc),
            SELL_AMOUNT,
            900e6,
            uint64(block.timestamp + 1 hours),
            RFQMarket.AccessMode.InviteOnly,
            invites,
            bytes32(0),
            ""
        );

        uint256 rfqId = _createInviteRFQ(providerA);
        vm.prank(providerB);
        vm.expectRevert(RFQMarket.ProviderNotAllowed.selector);
        market.submitQuote(
            rfqId, BUY_AMOUNT_B, uint64(block.timestamp + 10 minutes), keccak256("B")
        );
    }

    function testRejectsInvalidPairAmountsAndDeadline() public {
        address[] memory none = new address[](0);
        vm.prank(owner);
        assetRegistry.disablePair(address(usdc), address(eurc));
        vm.prank(taker);
        vm.expectRevert(RFQMarket.InvalidPair.selector);
        market.createRFQ(
            address(usdc),
            address(eurc),
            SELL_AMOUNT,
            900e6,
            uint64(block.timestamp + 1 hours),
            RFQMarket.AccessMode.Public,
            none,
            bytes32(0),
            ""
        );

        vm.prank(owner);
        assetRegistry.enablePair(address(usdc), address(eurc));
        vm.prank(taker);
        vm.expectRevert(RFQMarket.InvalidAmount.selector);
        market.createRFQ(
            address(usdc),
            address(eurc),
            0,
            0,
            uint64(block.timestamp + 1 hours),
            RFQMarket.AccessMode.Public,
            none,
            bytes32(0),
            ""
        );

        vm.prank(taker);
        vm.expectRevert(RFQMarket.InvalidExpiry.selector);
        market.createRFQ(
            address(usdc),
            address(eurc),
            SELL_AMOUNT,
            900e6,
            uint64(block.timestamp),
            RFQMarket.AccessMode.Public,
            none,
            bytes32(0),
            ""
        );
    }

    function testOnlyTakerCancelsAndAnyoneExpires() public {
        uint256 rfqId = _createPublicRFQ();
        vm.prank(outsider);
        vm.expectRevert(RFQMarket.Unauthorized.selector);
        market.cancelRFQ(rfqId);
        vm.prank(taker);
        market.cancelRFQ(rfqId);
        assertEq(uint256(market.getRFQ(rfqId).status), uint256(RFQMarket.RFQStatus.Cancelled));

        uint256 expiring = _createPublicRFQ();
        vm.warp(block.timestamp + 1 hours);
        market.expireRFQ(expiring);
        assertEq(uint256(market.getRFQ(expiring).status), uint256(RFQMarket.RFQStatus.Expired));
    }

    function testQuotesReserveCompeteReplaceCancelAndRelease() public {
        uint256 rfqId = _createPublicRFQ();
        uint256 quoteA = _quote(rfqId, providerA, BUY_AMOUNT_A);
        uint256 quoteB = _quote(rfqId, providerB, BUY_AMOUNT_B);
        assertEq(vault.reservedBalanceOf(providerA, address(eurc)), BUY_AMOUNT_A);
        assertEq(vault.reservedBalanceOf(providerB, address(eurc)), BUY_AMOUNT_B);

        vm.prank(providerA);
        market.replaceQuote(
            quoteA, BUY_AMOUNT_A + 10e6, uint64(block.timestamp + 20 minutes), keccak256("better")
        );
        assertEq(vault.reservedBalanceOf(providerA, address(eurc)), BUY_AMOUNT_A + 10e6);

        vm.prank(providerA);
        market.cancelQuote(quoteA);
        assertEq(vault.reservedBalanceOf(providerA, address(eurc)), 0);

        vm.warp(block.timestamp + 31 minutes);
        market.releaseQuote(quoteB);
        assertEq(vault.reservedBalanceOf(providerB, address(eurc)), 0);
    }

    function testReservationsReleaseAfterRFQCancellationAndExpiry() public {
        uint256 cancelledRfq = _createPublicRFQ();
        uint256 cancelledQuote = _quote(cancelledRfq, providerA, BUY_AMOUNT_A);
        vm.prank(taker);
        market.cancelRFQ(cancelledRfq);
        vm.prank(outsider);
        market.releaseQuote(cancelledQuote);
        assertEq(vault.reservedBalanceOf(providerA, address(eurc)), 0);

        uint256 expiredRfq = _createPublicRFQ();
        uint256 expiredQuote = _quote(expiredRfq, providerB, BUY_AMOUNT_B);
        vm.warp(block.timestamp + 1 hours);
        vm.prank(outsider);
        market.releaseQuote(expiredQuote);
        assertEq(vault.reservedBalanceOf(providerB, address(eurc)), 0);
    }

    function testQuotePaginationBoundaries() public {
        uint256 rfqId = _createPublicRFQ();
        _quote(rfqId, providerA, BUY_AMOUNT_A);
        _quote(rfqId, providerB, BUY_AMOUNT_B);
        assertEq(market.getRFQQuotes(rfqId, 0, 1).length, 1);
        assertEq(market.getRFQQuotes(rfqId, 2, 10).length, 0);

        vm.expectRevert(RFQMarket.InvalidPagination.selector);
        market.getRFQQuotes(rfqId, 0, 0);
        vm.expectRevert(RFQMarket.InvalidPagination.selector);
        market.getRFQQuotes(rfqId, 3, 1);
    }

    function testRejectsBadQuotesDuplicateAndInsufficientLiquidity() public {
        uint256 rfqId = _createPublicRFQ();
        vm.prank(providerA);
        vm.expectRevert(RFQMarket.InvalidAmount.selector);
        market.submitQuote(rfqId, 899e6, uint64(block.timestamp + 10 minutes), keccak256("low"));

        _quote(rfqId, providerA, BUY_AMOUNT_A);
        vm.prank(providerA);
        vm.expectRevert(RFQMarket.DuplicateActiveQuote.selector);
        market.submitQuote(
            rfqId, BUY_AMOUNT_A, uint64(block.timestamp + 10 minutes), keccak256("duplicate")
        );

        uint256 secondRfq = _createPublicRFQ();
        vm.prank(providerA);
        vm.expectRevert(LiquidityVault.InsufficientAvailable.selector);
        market.submitQuote(
            secondRfq, 2_000_000e6, uint64(block.timestamp + 10 minutes), keccak256("too-large")
        );
    }
}
