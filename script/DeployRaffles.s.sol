//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Raffles} from "../src/Raffles.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../script/Interactions.s.sol";

contract DeployRaffles is Script {
    //Deploys Raffles contract onchain
    function run() external returns (Raffles, HelperConfig) {
        return deployRafflesContract();
    }

    function deployRafflesContract() public returns (Raffles, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // local => deploy mocks
        // sepolia => get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator);
        }
        //Fund the newly created subscription
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.linkToken);

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
        //Add Raffle as a consumer on the VRF Coordinator
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffles), config.vrfCoordinator, config.subscriptionId);

        return (raffles, helperConfig);
    }
}
