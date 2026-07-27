// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console2 } from "forge-std/Script.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { AssetRegistry } from "../contracts/AssetRegistry.sol";
import { ProviderRegistry } from "../contracts/ProviderRegistry.sol";
import { LiquidityVault } from "../contracts/LiquidityVault.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";
import { SettlementRegistry } from "../contracts/SettlementRegistry.sol";

contract Deploy is Script {
    uint256 internal constant ARC_TESTNET_CHAIN_ID = 5_042_002;
    address internal constant OFFICIAL_USDC = 0x3600000000000000000000000000000000000000;
    address internal constant OFFICIAL_EURC = 0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a;

    function run() external {
        require(block.chainid == ARC_TESTNET_CHAIN_ID, "Arc Testnet only");
        require(OFFICIAL_USDC.code.length != 0 && OFFICIAL_EURC.code.length != 0, "missing token");
        require(
            IERC20Metadata(OFFICIAL_USDC).decimals() == 6
                && IERC20Metadata(OFFICIAL_EURC).decimals() == 6,
            "unexpected decimals"
        );

        uint256 rawProtocolFeeBps = vm.envOr("PROTOCOL_FEE_BPS", uint256(0));
        require(rawProtocolFeeBps <= 50, "fee too high");
        // rawProtocolFeeBps is capped well below uint16 max.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint16 protocolFeeBps = uint16(rawProtocolFeeBps);

        vm.startBroadcast();
        (, address deployer,) = vm.readCallers();
        require(deployer != address(0), "missing broadcast signer");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);
        AssetRegistry assets = new AssetRegistry(deployer);
        ProviderRegistry providers = new ProviderRegistry(deployer);
        SettlementRegistry settlements = new SettlementRegistry(deployer);
        LiquidityVault vault = new LiquidityVault(deployer, assets);
        RFQMarket market =
            new RFQMarket(assets, providers, vault, settlements, feeRecipient, protocolFeeBps);

        providers.setMarketOnce(address(market));
        settlements.setMarketOnce(address(market));
        vault.setMarketOnce(address(market));

        assets.registerAsset(
            OFFICIAL_USDC,
            "USDC",
            "Circle stablecoin on Arc Testnet",
            keccak256("https://docs.arc.io/arc/references/contract-addresses#usdc")
        );
        assets.registerAsset(
            OFFICIAL_EURC,
            "EURC",
            "Circle stablecoin on Arc Testnet",
            keccak256("https://docs.arc.io/arc/references/contract-addresses#eurc")
        );
        assets.enablePair(OFFICIAL_USDC, OFFICIAL_EURC);
        assets.enablePair(OFFICIAL_EURC, OFFICIAL_USDC);
        assets.setPairLimits(assets.getPairId(OFFICIAL_USDC, OFFICIAL_EURC), 1e6, 10_000_000e6);
        assets.setPairLimits(assets.getPairId(OFFICIAL_EURC, OFFICIAL_USDC), 1e6, 10_000_000e6);
        vm.stopBroadcast();

        console2.log("Network: Arc Testnet");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Fee recipient:", feeRecipient);
        console2.log("Protocol fee bps:", protocolFeeBps);
        console2.log("AssetRegistry:", address(assets));
        console2.log("ProviderRegistry:", address(providers));
        console2.log("SettlementRegistry:", address(settlements));
        console2.log("LiquidityVault:", address(vault));
        console2.log("RFQMarket:", address(market));
    }
}
