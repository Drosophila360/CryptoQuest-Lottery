//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Raffles} from "../src/Raffles.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployRaffles is Script {
    function run() public {}

    function deployRafflesContract() public returns (Raffles, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // local => deploy mocks
        // sepolia => get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {}

        vm.startBroadcast();
        Raffles raffles = new Raffles(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
        return (raffles, helperConfig);
    }
}
