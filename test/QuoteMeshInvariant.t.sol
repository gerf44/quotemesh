// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { AssetRegistry } from "../contracts/AssetRegistry.sol";
import { ProviderRegistry } from "../contracts/ProviderRegistry.sol";
import { LiquidityVault } from "../contracts/LiquidityVault.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";
import { SettlementRegistry } from "../contracts/SettlementRegistry.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract VaultHandler {
    LiquidityVault public immutable vault;
    RFQMarket public immutable market;
    MockERC20 public immutable token;
    address public immutable provider;

    constructor(LiquidityVault vault_, RFQMarket market_, MockERC20 token_, address provider_) {
        vault = vault_;
        market = market_;
        token = token_;
        provider = provider_;
    }

    function reserve(uint96 rawAmount) external {
        uint256 available = vault.availableBalanceOf(provider, address(token));
        if (available == 0) return;
        uint256 amount = (uint256(rawAmount) % available) + 1;
        vmPrank(address(market));
        vault.reserve(provider, address(token), amount);
    }

    function release(uint96 rawAmount) external {
        uint256 reserved = vault.reservedBalanceOf(provider, address(token));
        if (reserved == 0) return;
        uint256 amount = (uint256(rawAmount) % reserved) + 1;
        vmPrank(address(market));
        vault.release(provider, address(token), amount);
    }

    function vmPrank(address sender) private {
        address hevm = address(uint160(uint256(keccak256("hevm cheat code"))));
        (bool ok,) = hevm.call(abi.encodeWithSignature("prank(address)", sender));
        require(ok, "prank failed");
    }
}

contract QuoteMeshInvariantTest is StdInvariant, Test {
    address internal owner = makeAddr("owner");
    address internal provider = makeAddr("provider");
    address internal feeRecipient = makeAddr("feeRecipient");
    MockERC20 internal usdc;
    MockERC20 internal eurc;
    AssetRegistry internal assetRegistry;
    ProviderRegistry internal providerRegistry;
    LiquidityVault internal vault;
    SettlementRegistry internal settlementRegistry;
    RFQMarket internal market;
    VaultHandler internal handler;
    uint256 internal initialProviderLiability;

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        eurc = new MockERC20("Euro Coin", "EURC", 6);
        vm.startPrank(owner);
        assetRegistry = new AssetRegistry(owner);
        assetRegistry.registerAsset(address(usdc), "USDC", "stablecoin", keccak256("usdc"));
        assetRegistry.registerAsset(address(eurc), "EURC", "stablecoin", keccak256("eurc"));
        assetRegistry.enablePair(address(usdc), address(eurc));
        providerRegistry = new ProviderRegistry(owner);
        settlementRegistry = new SettlementRegistry(owner);
        vault = new LiquidityVault(owner, assetRegistry);
        market = new RFQMarket(
            assetRegistry, providerRegistry, vault, settlementRegistry, feeRecipient, 10
        );
        providerRegistry.setMarketOnce(address(market));
        settlementRegistry.setMarketOnce(address(market));
        vault.setMarketOnce(address(market));
        vm.stopPrank();

        eurc.mint(provider, 2_000_000e6);
        vm.startPrank(provider);
        eurc.approve(address(vault), type(uint256).max);
        vault.deposit(address(eurc), 2_000_000e6);
        vm.stopPrank();

        handler = new VaultHandler(vault, market, eurc, provider);
        targetContract(address(handler));
        initialProviderLiability = vault.availableBalanceOf(provider, address(eurc));
    }

    function invariant_VaultNeverFallsBelowLiabilities() public view {
        assertGe(vault.actualBalance(address(eurc)), vault.totalLiability(address(eurc)));
        assertGe(vault.actualBalance(address(usdc)), vault.totalLiability(address(usdc)));
    }

    function invariant_AvailablePlusReservedIsConserved() public view {
        assertEq(
            vault.availableBalanceOf(provider, address(eurc))
                + vault.reservedBalanceOf(provider, address(eurc)),
            initialProviderLiability
        );
    }
}
