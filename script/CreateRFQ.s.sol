// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";

contract CreateRFQ is Script {
    function run() external {
        RFQMarket market = RFQMarket(vm.envAddress("RFQ_MARKET_ADDRESS"));
        address[] memory noInvites = new address[](0);
        vm.startBroadcast();
        market.createRFQ(
            vm.envAddress("SELL_TOKEN_ADDRESS"),
            vm.envAddress("BUY_TOKEN_ADDRESS"),
            vm.envUint("SELL_AMOUNT"),
            vm.envUint("MIN_BUY_AMOUNT"),
            uint64(block.timestamp + vm.envUint("RFQ_DURATION_SECONDS")),
            RFQMarket.AccessMode.Public,
            noInvites,
            vm.envOr("RFQ_METADATA_HASH", bytes32(0)),
            vm.envOr("RFQ_METADATA_URI", string(""))
        );
        vm.stopBroadcast();
    }
}
