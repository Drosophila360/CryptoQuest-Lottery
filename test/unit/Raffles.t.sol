// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {DeployRaffles} from "../../script/DeployRaffles.s.sol";
import {Raffles} from "../../src/Raffles.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Constants} from "../../script/Constants.s.sol";

contract RafflesTest is Test, Constants {
    Raffles public raffles;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public config;

    address public PLAYER;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    function setUp() public {
        PLAYER = makeAddr("player");
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
        address playerRecorded = raffles.getNumberOfPlayers(0);
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

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffles.enterRaffle{value: config.entranceFee}();
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testWinnerPickedEmitsEvent() public raffleEnteredAndTimePassed skipFork {
        vm.recordLogs();
        raffles.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        //Expect emmit
        vm.expectEmit(true, false, false, false, address(raffles));
        emit WinnerPicked(PLAYER);
        // 3. Act: Fulfill random words via mock coordinator to trigger the event
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffles));
    }
    /*//////////////////////////////////////////////////////////////
                            TEST REVERTS
    //////////////////////////////////////////////////////////////*/

    function testDontEnterRaffleWhenRaffleIsCalculatingWinner() public raffleEnteredAndTimePassed {
        raffles.performUpkeep("");
        //act
        vm.expectRevert(Raffles.Raffles__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffles.enterRaffle{value: config.entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                            Test checkUpkeep
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

    function testCheckUpkeepReturnsFalsewhenNotOpen() public raffleEnteredAndTimePassed {
        raffles.performUpkeep("");
        //act
        (bool upkeepNeeded,) = raffles.checkUpkeep("");
        //assert
        assert(!upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                            Test performUpkeep
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed {
        //Act
        vm.recordLogs();
        raffles.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        //Assert
        Raffles.RaffleState raffleState = raffles.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*//////////////////////////////////////////////////////////////
                            Test fulfillRandomWords
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        skipFork
        raffleEnteredAndTimePassed
    {
        //Arrange
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffles));
    }

    function testFulfillRandomWordsPicksWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed skipFork {
        //Arrange
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            //address newPlayer = makeAddr(string(abi.encodePacked("player", i)));
            hoax(newPlayer, STARTING_BALANCE);
            raffles.enterRaffle{value: config.entranceFee}();
        }
        uint256 startingTimestamp = raffles.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        //Act
        vm.recordLogs();
        raffles.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffles));
        //assert
        address recentWinner = raffles.getRecentWinner();
        Raffles.RaffleState raffleState = raffles.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = raffles.getLastTimeStamp();
        uint256 prize = config.entranceFee * (additionalEntrants + 1);
        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimestamp > startingTimestamp);
    }
}
