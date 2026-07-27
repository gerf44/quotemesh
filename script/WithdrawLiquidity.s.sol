// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { LiquidityVault } from "../contracts/LiquidityVault.sol";

contract WithdrawLiquidity is Script {
    function run() external {
        LiquidityVault vault = LiquidityVault(vm.envAddress("LIQUIDITY_VAULT_ADDRESS"));
        vm.startBroadcast();
        vault.withdraw(
            vm.envAddress("TOKEN_ADDRESS"),
            vm.envUint("TOKEN_AMOUNT"),
            vm.envAddress("WITHDRAW_RECIPIENT")
        );
        vm.stopBroadcast();
    }
}
