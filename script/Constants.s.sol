//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Constants {
    /*//////////////////////////////////////////////////////////////
                            MOCK VRF CONFIG
    //////////////////////////////////////////////////////////////*/
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint32 public constant MOCK_GAS_LIMIT_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;
    /*//////////////////////////////////////////////////////////////
                            RAFFLE CONFIG
    //////////////////////////////////////////////////////////////*/

    uint256 public constant SEPOLIA_ETH_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant FUND_AMOUNT = 5e18;
    uint256 public constant ENTRANCE_FEE = 1e16;
    uint256 public constant INTERVAL = 30 seconds;
    address public constant VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 public constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 public constant CALLBACK_GAS_LIMIT = 500000;
    uint256 public constant SUBSCRIPTION_ID =
        54896052414209198384540475977532817595842095014400813550267609867612162571856;
    address public constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public constant ACCOUNT = 0x802602c50f220BAc74354ee3Cf9A1e1C94c91803;
    address public constant DEFAULT_ACCOUNT = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    uint256 public constant STARTING_BALANCE = 10e18;
}
