// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {DeployRaffles} from "../../script/DeployRaffles.s.sol";
import {Raffles} from "../../src/Raffles.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RafflesTest is Test {
    Raffles public raffles;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public config;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10e18;

    /**
     * Events
     */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    function setUp() public {
        DeployRaffles deployRaffles = new DeployRaffles();
        (raffles, helperConfig) = deployRaffles.deployRafflesContract();
        //uint256 subId = raffles.getSubscriptionId();
        config = helperConfig.getConfig();
        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testRafflesInitiateInOpenState() public view {
        assert(raffles.getRaffleState() == Raffles.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                            ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRafflesRevertWithInsufficientETH() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        vm.expectRevert(Raffles.Raffles__NotEnoughETHEntered.selector);
        //Assert
        raffles.enterRaffle();
    }

    function testRafflesRecordPlayer() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffles.enterRaffle{value: config.entranceFee}();
        //Assert
        address playerRecorded = raffles.getPlayers(0);
        assert(playerRecorded == PLAYER);
    }

    /*//////////////////////////////////////////////////////////////
                            TEST EVENTS
    //////////////////////////////////////////////////////////////*/
    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        vm.expectEmit(true, false, false, false, address(raffles));
        emit RaffleEntered(PLAYER);
        //Assert
        raffles.enterRaffle{value: config.entranceFee}();
    }

    /**
     * function testWinnerPickedEmitsEvent() public {
     *     //Arrange
     *     vm.prank(PLAYER);
     *     //Ensure that the PLAYER enters the raffle first before the winner is picked
     *     raffles.enterRaffle{value: config.entranceFee}();
     *     // fast forward time so upkeep is needed
     *     vm.warp(block.timestamp + config.interval);
     *     vm.roll(block.number + 1);
     *     // request random number from chainlink vrf
     *     vm.recordLogs();
     *     raffles.performUpkeep("");
     *     Vm.Log[] memory entries = vm.getRecordedLogs();
     *     bytes32 requestId = entries[1].topics[1];
     *     //Expect emmit
     *     vm.expectEmit(true, false, false, false, address(raffles));
     *     emit WinnerPicked(PLAYER);
     *     // 3. Act: Fulfill random words via mock coordinator to trigger the event
     *     VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffles));
     * }
     */
    function testDontEnterRaffleWhenRaffleIsCalculatingWinner() public {
        //Arrange
        vm.prank(PLAYER);
        //Ensure that the PLAYER enters the raffle
        raffles.enterRaffle{value: config.entranceFee}();
        // fast forward time so upkeep is needed
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        // request random number from chainlink vrf
        raffles.performUpkeep("");
        //act
        vm.expectRevert(Raffles.Raffles__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffles.enterRaffle{value: config.entranceFee}();
    }
    /*//////////////////////////////////////////////////////////////
                            TEST CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseWhenNoBalance() public {
        //Arrange
        // fast forward time so upkeep is needed
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        //act
        (bool upkeepNeeded,) = raffles.checkUpkeep("");
        //assert
        assert(!upkeepNeeded);

    }
    function testCheckUpkeepReturnsFalsewhenNotOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffles.enterRaffle{value: config.entranceFee}();
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        raffles.performUpkeep("");
        //act
        (bool upkeepNeeded,) = raffles.checkUpkeep("");
        //assert
        assert(!upkeepNeeded);
    }
}
