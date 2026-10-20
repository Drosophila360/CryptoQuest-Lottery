// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Constants} from "../../script/Constants.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffles} from "../../script/DeployRaffles.s.sol";
import {DeployRafflesLocally} from "../../script/DeployRafflesLocally.s.sol";
import {CreateSubscription} from "../../script/Interactions/CreateSubscription.s.sol";
import {AddConsumer} from "../../script/Interactions/AddConsumer.s.sol";
import {FundSubscription} from "../../script/Interactions/FundSubscription.s.sol";
import {Raffles} from "../../src/Raffles.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../mocks/LinkToken.sol";

contract DeploymentScriptsTest is Test, Constants {
    function testHelperConfigReturnsSepoliaConfiguration() public {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfigByChainId(SEPOLIA_ETH_CHAIN_ID);

        assertEq(config.vrfCoordinator, VRF_COORDINATOR);
        assertEq(config.linkToken, LINK_TOKEN);
        assertEq(config.account, ACCOUNT);
        assertEq(config.subscriptionId, SUBSCRIPTION_ID);
        assertEq(config.entranceFee, ENTRANCE_FEE);
        assertEq(config.interval, INTERVAL);
        assertEq(config.keyHash, KEY_HASH);
        assertEq(config.callbackGasLimit, CALLBACK_GAS_LIMIT);
    }

    function testHelperConfigRevertsForUnsupportedChain() public {
        HelperConfig helperConfig = new HelperConfig();

        vm.expectRevert(HelperConfig.HelperConfig__InvalidChainId.selector);
        helperConfig.getNetworkConfigByChainId(1);
    }

    function testHelperConfigCreatesAndCachesLocalMocks() public {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory firstConfig = helperConfig.getOrCreateAnvilConfig();
        HelperConfig.NetworkConfig memory cachedConfig = helperConfig.getOrCreateAnvilConfig();

        assertTrue(firstConfig.vrfCoordinator.code.length > 0);
        assertTrue(firstConfig.linkToken.code.length > 0);
        assertEq(firstConfig.vrfCoordinator, cachedConfig.vrfCoordinator);
        assertEq(firstConfig.linkToken, cachedConfig.linkToken);
        assertEq(firstConfig.account, DEFAULT_ACCOUNT);
        assertEq(firstConfig.subscriptionId, 0);
    }

    function testLocalDeploymentScriptDeploysAndWiresRaffle() public {
        DeployRafflesLocally deployment = new DeployRafflesLocally();
        Raffles raffle = deployment.raffle();

        assertTrue(address(raffle).code.length > 0);
        assertEq(raffle.getSubscriptionId(), deployment.subscriptionId());
        assertEq(raffle.getEntranceFee(), ENTRANCE_FEE);
        assertEq(raffle.getInterval(), INTERVAL);
        assertTrue(deployment.coordinator().consumerIsAdded(deployment.subscriptionId(), address(raffle)));

        (uint96 balance,,,,) = deployment.coordinator().getSubscription(deployment.subscriptionId());
        assertEq(balance, FUND_AMOUNT * 100);
    }

    function testDeployRafflesRunUsesLocalDeployment() public {
        DeployRaffles deployRaffles = new DeployRaffles();

        (Raffles raffle, HelperConfig helperConfig) = deployRaffles.run();

        assertTrue(address(raffle).code.length > 0);
        assertEq(raffle.getEntranceFee(), ENTRANCE_FEE);
        assertTrue(helperConfig.getConfig().vrfCoordinator.code.length > 0);
    }

    function testCreateSubscriptionReturnsCoordinatorAndCreatedSubscription() public {
        VRFCoordinatorV2_5Mock coordinator = _newCoordinator();
        CreateSubscription createSubscription = new CreateSubscription();

        (uint256 subscriptionId, address returnedCoordinator) =
            createSubscription.createSubscription(address(coordinator), address(this));

        (,,,, address[] memory consumers) = coordinator.getSubscription(subscriptionId);
        assertEq(returnedCoordinator, address(coordinator));
        assertEq(consumers.length, 0);
    }

    function testAddConsumerScriptAddsConsumerToSubscription() public {
        VRFCoordinatorV2_5Mock coordinator = _newCoordinator();
        uint256 subscriptionId = coordinator.createSubscription();
        address consumer = makeAddr("consumer");
        AddConsumer addConsumer = new AddConsumer();

        addConsumer.addConsumer(consumer, address(coordinator), subscriptionId, address(this));

        assertTrue(coordinator.consumerIsAdded(subscriptionId, consumer));
    }

    function testFundSubscriptionScriptFundsLocalSubscription() public {
        VRFCoordinatorV2_5Mock coordinator = _newCoordinator();
        uint256 subscriptionId = coordinator.createSubscription();
        FundSubscription fundSubscription = new FundSubscription();

        fundSubscription.fundSubscription(address(coordinator), subscriptionId, address(0), address(this));

        (uint96 balance,,,,) = coordinator.getSubscription(subscriptionId);
        assertEq(balance, FUND_AMOUNT * 100);
    }

    function testFundSubscriptionScriptSkipsAdequatelyFundedExternalSubscription() public {
        uint256 anvilChainId = vm.getChainId();
        vm.chainId(SEPOLIA_ETH_CHAIN_ID);

        VRFCoordinatorV2_5Mock coordinator = _newCoordinator();
        uint256 subscriptionId = coordinator.createSubscription();
        coordinator.fundSubscription(subscriptionId, FUND_AMOUNT);
        FundSubscription fundSubscription = new FundSubscription();

        fundSubscription.fundSubscription(address(coordinator), subscriptionId, address(0), address(this));

        (uint96 balance,,,,) = coordinator.getSubscription(subscriptionId);
        assertEq(balance, FUND_AMOUNT);
        vm.chainId(anvilChainId);
    }

    function testFundSubscriptionScriptTransfersLinkForExternalSubscription() public {
        uint256 anvilChainId = vm.getChainId();
        vm.chainId(SEPOLIA_ETH_CHAIN_ID);

        VRFCoordinatorV2_5Mock coordinator = _newCoordinator();
        LinkToken linkToken = new LinkToken();
        coordinator.setLINKAndLINKNativeFeed(address(linkToken), address(0));
        uint256 subscriptionId = coordinator.createSubscription();
        FundSubscription fundSubscription = new FundSubscription();

        fundSubscription.fundSubscription(address(coordinator), subscriptionId, address(linkToken), address(this));

        (uint96 balance,,,,) = coordinator.getSubscription(subscriptionId);
        assertEq(balance, FUND_AMOUNT);
        assertEq(linkToken.balanceOf(address(coordinator)), FUND_AMOUNT);
        vm.chainId(anvilChainId);
    }

    function _newCoordinator() private returns (VRFCoordinatorV2_5Mock) {
        return new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_LIMIT_LINK, MOCK_WEI_PER_UNIT_LINK);
    }
}
