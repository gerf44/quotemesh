// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { RFQMarket } from "../contracts/RFQMarket.sol";

contract AcceptQuote is Script {
    function run() external {
        RFQMarket market = RFQMarket(vm.envAddress("RFQ_MARKET_ADDRESS"));
        vm.startBroadcast();
        market.acceptQuote(
            vm.envUint("RFQ_ID"), vm.envUint("QUOTE_ID"), vm.envUint("MIN_EXPECTED_BUY_AMOUNT")
        );
        vm.stopBroadcast();
    }
}
