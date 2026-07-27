// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";

contract SubmitQuote is Script {
    function run() external {
        RFQMarket market = RFQMarket(vm.envAddress("RFQ_MARKET_ADDRESS"));
        vm.startBroadcast();
        market.submitQuote(
            vm.envUint("RFQ_ID"),
            vm.envUint("BUY_AMOUNT"),
            uint64(block.timestamp + vm.envUint("QUOTE_DURATION_SECONDS")),
            vm.envOr("PROVIDER_REFERENCE", bytes32(0))
        );
        vm.stopBroadcast();
    }
}
