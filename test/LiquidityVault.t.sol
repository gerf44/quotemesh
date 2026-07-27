// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { QuoteMeshTestBase } from "./QuoteMeshTestBase.sol";
import { LiquidityVault } from "../contracts/LiquidityVault.sol";
import { FeeOnTransferMock } from "./mocks/MockERC20.sol";

contract LiquidityVaultTest is QuoteMeshTestBase {
    function testDepositsMultipleProvidersAndReportsSolvency() public view {
        assertEq(vault.availableBalanceOf(providerA, address(eurc)), 2_000_000e6);
        assertEq(vault.availableBalanceOf(providerB, address(eurc)), 2_000_000e6);
        assertEq(vault.totalLiability(address(eurc)), 4_000_000e6);
        assertTrue(vault.isSolvent(address(eurc)));
    }

    function testReserveReleaseAndWithdrawalBoundaries() public {
        vm.prank(address(market));
        vault.reserve(providerA, address(eurc), 500e6);
        assertEq(vault.reservedBalanceOf(providerA, address(eurc)), 500e6);

        vm.prank(providerA);
        vm.expectRevert(LiquidityVault.InsufficientAvailable.selector);
        vault.withdraw(address(eurc), 2_000_000e6, providerA);

        vm.prank(address(market));
        vault.release(providerA, address(eurc), 500e6);
        vm.prank(providerA);
        vault.withdraw(address(eurc), 2_000_000e6, providerA);
        assertEq(vault.availableBalanceOf(providerA, address(eurc)), 0);
    }

    function testRejectsUnauthorizedReserveZeroDepositAndUnsupportedAsset() public {
        vm.prank(outsider);
        vm.expectRevert(LiquidityVault.UnauthorizedMarket.selector);
        vault.reserve(providerA, address(eurc), 1e6);

        vm.prank(providerA);
        vm.expectRevert(LiquidityVault.InvalidAmount.selector);
        vault.deposit(address(eurc), 0);

        FeeOnTransferMock unknown = new FeeOnTransferMock();
        unknown.mint(providerA, 100e6);
        vm.startPrank(providerA);
        unknown.approve(address(vault), type(uint256).max);
        vm.expectRevert(LiquidityVault.UnsupportedAsset.selector);
        vault.deposit(address(unknown), 100e6);
        vm.stopPrank();
    }

    function testRejectsFeeOnTransferToken() public {
        FeeOnTransferMock feeToken = new FeeOnTransferMock();
        vm.prank(owner);
        assetRegistry.registerAsset(
            address(feeToken), "FEE", "test-only", keccak256("test-fee-token")
        );
        feeToken.mint(providerA, 100e6);
        vm.startPrank(providerA);
        feeToken.approve(address(vault), type(uint256).max);
        vm.expectRevert(LiquidityVault.UnexpectedTokenBehavior.selector);
        vault.deposit(address(feeToken), 100e6);
        vm.stopPrank();
        assertEq(vault.totalLiability(address(feeToken)), 0);
    }

    function testUnexpectedDirectTransferCreatesUntouchedSurplus() public {
        eurc.mint(outsider, 50e6);
        vm.prank(outsider);
        assertTrue(eurc.transfer(address(vault), 50e6));
        assertEq(vault.actualBalance(address(eurc)) - vault.totalLiability(address(eurc)), 50e6);
        assertTrue(vault.isSolvent(address(eurc)));
    }

    function testOwnerCannotWithdrawProviderFunds() public {
        vm.prank(owner);
        vm.expectRevert(LiquidityVault.InsufficientAvailable.selector);
        vault.withdraw(address(eurc), 1e6, owner);
        assertEq(vault.availableBalanceOf(providerA, address(eurc)), 2_000_000e6);
    }
}
