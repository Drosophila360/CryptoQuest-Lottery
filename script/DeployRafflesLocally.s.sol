//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Raffles} from "../src/Raffles.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Constants} from "./Constants.s.sol";

/**
 * @notice Deploys and configures the local raffle and its VRF mock.
 * @dev The setup is atomic because VRF v2.5 mock subscription IDs depend on the block hash.
 */
contract DeployRafflesLocally is Constants {
    Raffles public raffle;
    VRFCoordinatorV2_5Mock public coordinator;
    uint256 public subscriptionId;

    event LocalRaffleDeployed(address indexed raffle, address indexed coordinator, uint256 subscriptionId);

    constructor() {
        coordinator = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_LIMIT_LINK, MOCK_WEI_PER_UNIT_LINK);
        subscriptionId = coordinator.createSubscription();
        coordinator.fundSubscription(subscriptionId, FUND_AMOUNT * 100);

        raffle = new Raffles(
            ENTRANCE_FEE,
            INTERVAL,
            address(coordinator),
            KEY_HASH,
            subscriptionId,
            CALLBACK_GAS_LIMIT
        );
        coordinator.addConsumer(subscriptionId, address(raffle));

        emit LocalRaffleDeployed(address(raffle), address(coordinator), subscriptionId);
    }
}
