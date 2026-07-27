// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { QuoteMeshTestBase } from "./QuoteMeshTestBase.sol";
import { ProviderRegistry } from "../contracts/ProviderRegistry.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";

contract ProviderRegistryTest is QuoteMeshTestBase {
    function testProviderRegistrationUpdatePauseResumeAndVerification() public {
        ProviderRegistry.ProviderProfile memory profile =
            providerRegistry.providerProfile(providerA);
        assertTrue(profile.active);

        vm.startPrank(providerA);
        providerRegistry.updateProviderProfile("ipfs://updated", keccak256("updated"));
        providerRegistry.pauseMyProviderAccount();
        assertFalse(providerRegistry.isActiveProvider(providerA));
        providerRegistry.resumeMyProviderAccount();
        vm.stopPrank();
        assertTrue(providerRegistry.isActiveProvider(providerA));

        vm.prank(owner);
        providerRegistry.setQuoteMeshVerification(providerA, true);
        profile = providerRegistry.providerProfile(providerA);
        assertTrue(profile.quoteMeshVerified);
        assertEq(profile.metadataURI, "ipfs://updated");
    }

    function testRejectsDuplicateAndInvalidRegistration() public {
        vm.prank(providerA);
        vm.expectRevert(ProviderRegistry.AlreadyRegistered.selector);
        providerRegistry.registerProvider("ipfs://again", keccak256("again"));

        vm.prank(outsider);
        vm.expectRevert(ProviderRegistry.InvalidProfile.selector);
        providerRegistry.registerProvider("", bytes32(0));
    }

    function testOnlyMarketRecordsStatistics() public {
        vm.prank(outsider);
        vm.expectRevert(ProviderRegistry.UnauthorizedMarket.selector);
        providerRegistry.recordQuoteSubmitted(providerA);

        uint256 rfqId = _createPublicRFQ();
        _quote(rfqId, providerA, BUY_AMOUNT_A);
        ProviderRegistry.ProviderProfile memory profile =
            providerRegistry.providerProfile(providerA);
        assertEq(profile.quotesSubmitted, 1);
    }

    function testPausedProviderCannotQuoteButCanWithdraw() public {
        vm.prank(providerA);
        providerRegistry.pauseMyProviderAccount();
        uint256 rfqId = _createPublicRFQ();
        vm.prank(providerA);
        vm.expectRevert(RFQMarket.ProviderNotAllowed.selector);
        market.submitQuote(
            rfqId, BUY_AMOUNT_A, uint64(block.timestamp + 10 minutes), keccak256("ref")
        );

        uint256 before = eurc.balanceOf(providerA);
        vm.prank(providerA);
        vault.withdraw(address(eurc), 100e6, providerA);
        assertEq(eurc.balanceOf(providerA), before + 100e6);
    }
}
