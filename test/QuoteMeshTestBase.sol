// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { AssetRegistry } from "../contracts/AssetRegistry.sol";
import { ProviderRegistry } from "../contracts/ProviderRegistry.sol";
import { LiquidityVault } from "../contracts/LiquidityVault.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";
import { SettlementRegistry } from "../contracts/SettlementRegistry.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

abstract contract QuoteMeshTestBase is Test {
    address internal owner = makeAddr("owner");
    address internal taker = makeAddr("taker");
    address internal providerA = makeAddr("providerA");
    address internal providerB = makeAddr("providerB");
    address internal outsider = makeAddr("outsider");
    address internal feeRecipient = makeAddr("feeRecipient");

    MockERC20 internal usdc;
    MockERC20 internal eurc;
    AssetRegistry internal assetRegistry;
    ProviderRegistry internal providerRegistry;
    LiquidityVault internal vault;
    SettlementRegistry internal settlementRegistry;
    RFQMarket internal market;

    uint256 internal constant SELL_AMOUNT = 1_000e6;
    uint256 internal constant BUY_AMOUNT_A = 920e6;
    uint256 internal constant BUY_AMOUNT_B = 925e6;

    function setUp() public virtual {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        eurc = new MockERC20("Euro Coin", "EURC", 6);

        vm.startPrank(owner);
        assetRegistry = new AssetRegistry(owner);
        assetRegistry.registerAsset(address(usdc), "USDC", "stablecoin", keccak256("official-usdc"));
        assetRegistry.registerAsset(address(eurc), "EURC", "stablecoin", keccak256("official-eurc"));
        assetRegistry.enablePair(address(usdc), address(eurc));
        assetRegistry.enablePair(address(eurc), address(usdc));
        assetRegistry.setPairLimits(
            assetRegistry.getPairId(address(usdc), address(eurc)), 1e6, 10_000_000e6
        );
        assetRegistry.setPairLimits(
            assetRegistry.getPairId(address(eurc), address(usdc)), 1e6, 10_000_000e6
        );

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

        usdc.mint(taker, 10_000_000e6);
        eurc.mint(taker, 10_000_000e6);
        usdc.mint(providerA, 10_000_000e6);
        eurc.mint(providerA, 10_000_000e6);
        usdc.mint(providerB, 10_000_000e6);
        eurc.mint(providerB, 10_000_000e6);

        _registerAndFund(providerA, 2_000_000e6, 2_000_000e6);
        _registerAndFund(providerB, 2_000_000e6, 2_000_000e6);

        vm.startPrank(taker);
        usdc.approve(address(vault), type(uint256).max);
        eurc.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _registerAndFund(address provider, uint256 usdcAmount, uint256 eurcAmount) internal {
        vm.startPrank(provider);
        providerRegistry.registerProvider(
            string.concat("ipfs://", vm.toString(provider)), keccak256(abi.encode(provider))
        );
        usdc.approve(address(vault), type(uint256).max);
        eurc.approve(address(vault), type(uint256).max);
        vault.deposit(address(usdc), usdcAmount);
        vault.deposit(address(eurc), eurcAmount);
        vm.stopPrank();
    }

    function _createPublicRFQ() internal returns (uint256 rfqId) {
        address[] memory none = new address[](0);
        vm.prank(taker);
        rfqId = market.createRFQ(
            address(usdc),
            address(eurc),
            SELL_AMOUNT,
            900e6,
            uint64(block.timestamp + 1 hours),
            RFQMarket.AccessMode.Public,
            none,
            keccak256("rfq"),
            "ipfs://rfq"
        );
    }

    function _createInviteRFQ(address invitedProvider) internal returns (uint256 rfqId) {
        address[] memory inviteList = new address[](1);
        inviteList[0] = invitedProvider;
        vm.prank(taker);
        rfqId = market.createRFQ(
            address(usdc),
            address(eurc),
            SELL_AMOUNT,
            900e6,
            uint64(block.timestamp + 1 hours),
            RFQMarket.AccessMode.InviteOnly,
            inviteList,
            keccak256("invite-rfq"),
            "ipfs://invite-rfq"
        );
    }

    function _quote(uint256 rfqId, address provider, uint256 buyAmount)
        internal
        returns (uint256 quoteId)
    {
        vm.prank(provider);
        quoteId = market.submitQuote(
            rfqId, buyAmount, uint64(block.timestamp + 30 minutes), keccak256("provider-ref")
        );
    }
}
