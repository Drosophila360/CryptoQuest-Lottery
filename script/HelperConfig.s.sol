//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Raffles} from "../src/Raffles.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract Constants {
    /**
     * VRF Constants
     */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint32 public constant MOCK_GAS_LIMIT_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant SEPOLIA_ETH_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant FUND_AMOUNT = 5e18;
    uint256 public constant ENTRANCE_FEE = 1e16;
    uint256 public constant INTERVAL = 30 seconds;
    address public constant VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 public constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 public constant CALLBACK_GAS_LIMIT = 50000;
    uint256 public constant SUBSCRIPTION_ID = 0x0;
    address public constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
}

contract HelperConfig is Constants, Script {
    /**
     * Errors
     */
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
    }

    NetworkConfig public LocalNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfig;

    constructor() {
        networkConfig[SEPOLIA_ETH_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getNetworkConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfig[chainId].vrfCoordinator != address(0)) {
            return networkConfig[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL,
            vrfCoordinator: VRF_COORDINATOR,
            keyHash: KEY_HASH,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            subscriptionId: SUBSCRIPTION_ID,
            linkToken: LINK_TOKEN
        });
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getNetworkConfigByChainId(block.chainid);
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        // Check if we set active network config
        if (LocalNetworkConfig.vrfCoordinator != address(0)) {
            return LocalNetworkConfig;
        }

        // deploy mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_LIMIT_LINK, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        LocalNetworkConfig = NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL,
            vrfCoordinator: address(vrfCoordinatorMock),
            keyHash: KEY_HASH,
            callbackGasLimit: uint32(CALLBACK_GAS_LIMIT),
            subscriptionId: 0x0,
            linkToken: address(linkToken)
        });

        return LocalNetworkConfig;
    }
}
