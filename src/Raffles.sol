//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 *@title A sample Raffles contract
 * @author Kisavi De Muthama
 * @notice This contract is for creating a sample Raffles contract
 * @dev Source: cyfrin updraft course. Thanks to Patrick Collins for the course
 */

contract Raffles is VRFConsumerBaseV2Plus {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when ETH sent is less than the required entrance fee.
    error Raffles__NotEnoughETHEntered();
    /// @notice Thrown when checkUpkeep returns false during performUpkeep execution.
    /// @param currentBalance Current balance of the contract in wei.
    /// @param numPlayers Current number of registered players.
    /// @param raffleState Current state of the raffle (0 = OPEN, 1 = CALCULATING_WINNER).
    error Raffles__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
    /// @notice Thrown when the ETH transfer to the winning address fails.
    error Raffles__TransferFailed();
    /// @notice Thrown when a player attempts to enter the raffle while it is not in the OPEN state.
    error Raffles__RaffleNotOpen();

    /*//////////////////////////////////////////////////////////////
                            TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Represents the operational state of the raffle.
    enum RaffleState {
        OPEN,
        CALCULATING_WINNER
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable I_ENTRANCE_FEE;
    uint256 private immutable I_INTERVAL;
    address payable[] private sPlayers;
    bytes32 private immutable I_KEY_HASH;
    uint32 private immutable I_CALLBACK_GAS_LIMIT;
    uint256 private immutable I_SUBSCRIPTION_ID;
    uint256 private sLastTimestamp;
    address private sRecentWinner;
    RaffleState private sRaffleState;

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTRANCE_FEE = entranceFee;
        I_INTERVAL = interval;
        I_CALLBACK_GAS_LIMIT = callbackGasLimit;
        I_KEY_HASH = keyHash;
        I_SUBSCRIPTION_ID = subscriptionId;
        sLastTimestamp = block.timestamp;
        sRaffleState = RaffleState.OPEN;
    }

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a player successfully enters the raffle.
     * @param player Address of the player who entered.
     */
    event RaffleEntered(address indexed player);
    /**
     * @notice Emitted when a winner is picked for the raffle.
     * @param winner Address of the winning player.
     */
    event WinnerPicked(address indexed winner);
    /**
     * @notice Emitted when a request for a raffle winner is submitted.
     * @param requestId The ID of the request.
     */
    event RequestedRaffleWinner(uint256 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Allows a player to enter the raffle by paying the entrance fee.
     * @dev Reverts if msg.value is lower than entrance fee or if raffle is not OPEN.
     */
    function enterRaffle() external payable {
        //require(msg.value >= i_entranceFee, "Not enough ETH to enter raffle");
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffles__NotEnoughETHEntered();
        }
        if (sRaffleState != RaffleState.OPEN) {
            revert Raffles__RaffleNotOpen();
        }
        sPlayers.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @notice Called by Chainlink Automation nodes to check if a raffle draw should be triggered.
     * @dev Upkeep is needed if interval time has passed, state is OPEN, and contract has ETH & players.
     * @return upkeepNeeded True if condition for picking a winner is met.
     * @return performData Returns dummy bytes ("0x0") as data is unused.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = (block.timestamp - sLastTimestamp) >= I_INTERVAL;
        bool isOpen = (sRaffleState == RaffleState.OPEN);
        bool hasPlayers = (sPlayers.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (timeHasPassed && isOpen && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    /**
     * @notice Triggers the selection of a random winner via Chainlink VRF.
     * @dev Reverts if checkUpkeep returns false.
     */
    function performUpkeep(
        bytes memory /* performData */
    )
        external
    {
        //check if enough time has passed since the last raffle
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffles__UpkeepNotNeeded(address(this).balance, sPlayers.length, uint256(sRaffleState));
        }
        sRaffleState = RaffleState.CALCULATING_WINNER;
        //request random number from chainlink vrf
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: I_KEY_HASH,
            subId: I_SUBSCRIPTION_ID,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: I_CALLBACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        //captures the requestId returned by the VRF Coordinator
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        //emit your event passing the requestId
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @notice Callback function called by Chainlink VRF to deliver random numbers.
     * @dev Selects the winner using modulo arithmetic, resets state, and transfers balance.
     * @param randomWords Array of random values generated by Chainlink VRF.
     */
    function fulfillRandomWords(
        uint256,
        /* requestId */
        uint256[] calldata randomWords
    )
        internal
        override
    {
        //get a random index from the players array
        uint256 indexOfWinner = randomWords[0] % sPlayers.length;
        address payable recentWinner = sPlayers[indexOfWinner];

        //update all internal storage state first to avoid reentrancy attacks
        sRecentWinner = recentWinner;
        sRaffleState = RaffleState.OPEN;
        sPlayers = new address payable[](0);
        sLastTimestamp = block.timestamp;

        //emit event after all state updates are done to avoid reentrancy attacks
        emit WinnerPicked(recentWinner);

        //transfer the entire balance of the contract to the winner
        //forge-fmt: disable-next-line low-level-calls
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffles__TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the entrance fee required to participate in the raffle.
     * @return The entrance fee in wei.
     */
    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }

    /**
     * @notice Returns the current state of the raffle.
     * @return The RaffleState enum value.
     */
    function getRaffleState() external view returns (RaffleState) {
        return sRaffleState;
    }

    /**
     * @notice Returns a player address at a specific index in the players array.
     * @param indexOfPlayers Array index.
     * @return Address of the player.
     */
    function getPlayer(uint256 indexOfPlayers) external view returns (address) {
        return sPlayers[indexOfPlayers];
    }

    /**
     * @notice Returns the total number of players currently in the raffle.
     * @return Number of players.
     */
    function getNumberOfPlayers(uint256 indexOfPlayers) external view returns (address) {
        return sPlayers[indexOfPlayers];
    }

    /**
     * @notice Returns the most recent winner of the raffle.
     * @return The address of the recent winner.
     */
    function getRecentWinner() external view returns (address) {
        return sRecentWinner;
    }

    /**
     * @notice Returns the Chainlink VRF subscription ID.
     * @return Subscription ID.
     */
    function getSubscriptionId() external view returns (uint256) {
        return I_SUBSCRIPTION_ID;
    }

    /**
     * @notice Returns the interval duration between raffle rounds.
     * @return Duration in seconds.
     */
    function getInterval() external view returns (uint256) {
        return I_INTERVAL;
    }

    /**
     * @notice Returns the timestamp when the last winner was picked.
     * @return Timestamp in seconds.
     */
    function getLastTimeStamp() external view returns (uint256) {
        return sLastTimestamp;
    }
}
