// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { QuoteMeshTestBase } from "./QuoteMeshTestBase.sol";
import { AssetRegistry } from "../contracts/AssetRegistry.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract AssetRegistryTest is QuoteMeshTestBase {
    function testRegistersOfficialAssetsAndDirectionalPairs() public view {
        AssetRegistry.AssetInfo memory asset = assetRegistry.assetInfo(address(usdc));
        assertEq(asset.symbol, "USDC");
        assertEq(asset.decimals, 6);
        assertTrue(asset.enabled);
        assertTrue(assetRegistry.isSupportedPair(address(usdc), address(eurc)));
        assertTrue(assetRegistry.isSupportedPair(address(eurc), address(usdc)));
    }

    function testRejectsDuplicateZeroAndBadDecimals() public {
        vm.startPrank(owner);
        vm.expectRevert(AssetRegistry.DuplicateAsset.selector);
        assetRegistry.registerAsset(address(usdc), "USDC", "stablecoin", bytes32(0));

        vm.expectRevert(AssetRegistry.InvalidAddress.selector);
        assetRegistry.registerAsset(address(0), "ZERO", "stablecoin", bytes32(0));

        MockERC20 bad = new MockERC20("Bad", "BAD", 19);
        vm.expectRevert(AssetRegistry.InvalidAsset.selector);
        assetRegistry.registerAsset(address(bad), "BAD", "stablecoin", bytes32(0));
        vm.stopPrank();
    }

    function testPairDisableAndLimits() public {
        bytes32 pairId = assetRegistry.getPairId(address(usdc), address(eurc));
        vm.startPrank(owner);
        assetRegistry.setPairLimits(pairId, 100e6, 200e6);
        AssetRegistry.PairInfo memory pair = assetRegistry.pairInfo(pairId);
        assertEq(pair.minAmount, 100e6);
        assertEq(pair.maxAmount, 200e6);
        assetRegistry.disablePair(address(usdc), address(eurc));
        vm.stopPrank();
        assertFalse(assetRegistry.isSupportedPair(address(usdc), address(eurc)));
    }

    function testRejectsIdenticalPairAndUnauthorizedConfiguration() public {
        vm.prank(owner);
        vm.expectRevert(AssetRegistry.IdenticalPair.selector);
        assetRegistry.enablePair(address(usdc), address(usdc));

        vm.prank(outsider);
        vm.expectRevert();
        assetRegistry.setAssetStatus(address(usdc), false);
    }

    function testRejectsInvalidPairLimits() public {
        bytes32 pairId = assetRegistry.getPairId(address(usdc), address(eurc));
        vm.prank(owner);
        vm.expectRevert(AssetRegistry.InvalidLimits.selector);
        assetRegistry.setPairLimits(pairId, 200e6, 100e6);
    }
}
