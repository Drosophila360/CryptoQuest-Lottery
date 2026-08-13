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
        HelperConfig.NetworkConfig memory Config = helperConfig.getConfig();

        vm.startBroadcast();
        Raffles raffles = new Raffles(
            Config.entranceFee,
            Config.interval,
            Config.vrfCoordinator,
            Config.keyHash,
            Config.subscriptionId,
            Config.callbackGasLimit
        );
        vm.stopBroadcast();
        return (raffles, helperConfig);
    }
}
