// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { ProviderRegistry } from "../contracts/ProviderRegistry.sol";

contract RegisterProvider is Script {
    function run() external {
        ProviderRegistry registry = ProviderRegistry(vm.envAddress("PROVIDER_REGISTRY_ADDRESS"));
        string memory metadataURI = vm.envString("PROVIDER_METADATA_URI");
        bytes32 profileHash = vm.envBytes32("PROVIDER_PROFILE_HASH");
        vm.startBroadcast();
        registry.registerProvider(metadataURI, profileHash);
        vm.stopBroadcast();
    }
}
