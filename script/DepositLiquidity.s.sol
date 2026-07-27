// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { LiquidityVault } from "../contracts/LiquidityVault.sol";

contract DepositLiquidity is Script {
    function run() external {
        address token = vm.envAddress("TOKEN_ADDRESS");
        uint256 amount = vm.envUint("TOKEN_AMOUNT");
        LiquidityVault vault = LiquidityVault(vm.envAddress("LIQUIDITY_VAULT_ADDRESS"));
        vm.startBroadcast();
        IERC20(token).approve(address(vault), amount);
        vault.deposit(token, amount);
        vm.stopBroadcast();
    }
}
