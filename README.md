# CryptoQuest Lottery

A secure, on-chain raffle and lottery system built on Ethereum using Foundry, Chainlink VRF v2.5, and Chainlink Automation. Players enter by sending a ticket fee, the raffle automatically tracks upkeep criteria, and a verifiable random winner is selected without relying on centralized randomness.

![Foundry](https://img.shields.io/badge/Foundry-FFDB1C?logo=foundry&logoColor=000000)
![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.19-363636?logo=solidity&logoColor=white)
![Chainlink](https://img.shields.io/badge/Chainlink-VRF%20v2.5-2A5ADA)

## Architecture & How It Works

This project follows a compact raffle architecture built around a single core contract, `Raffles.sol`, with deployment helper contracts for network configuration and upkeep settings.

- Players call `enterRaffle()` by sending the current raffle entrance fee.
- The contract records entrants in an array and keeps track of the raffle state.
- Chainlink Automation monitors the raffle through `checkUpkeep()`, which determines when the raffle is eligible for a draw.
- When conditions are met, the automation system invokes `performUpkeep()`, which triggers the VRF randomness request via `requestRandomWords()`.
- Chainlink VRF v2.5 completes the randomness request and calls `fulfillRandomWords()`, which selects the winner and resets the raffle for the next round.
- The raffle uses a `Checks-Effects-Interactions` flow to avoid unsafe state transitions and to reduce reentrancy exposure.

The core flow is:

1. User enters raffle
2. Raffle accumulates entrants and entrance fee
3. Automation checks for draw conditions
4. Contract requests random number from VRF
5. VRF callback selects a winner
6. Winner is paid and raffle restarts

## Tech Stack & Dependencies

- Solidity: `^0.8.19`
- Foundry: `forge`, `cast`, `anvil`, `chisel`
- Chainlink VRF v2.5: randomness oracle and coordinator integration
- Chainlink Automation: upkeep monitoring and execution
- OpenZeppelin Contracts: security-focused standard library features and utilities
- Test framework: Forge tests with Solidity-based unit/integration testing

Key dependencies and config are defined in the repository's Foundry setup and imported interfaces/contracts.

## Key Features

- Automated winner selection using Chainlink VRF and Automation
- Secure raffle lifecycle with explicit state checks and custom errors
- Gas-efficient custom errors instead of verbose revert strings
- Event tracking for entries, draws, and winner settlement
- Entrance fee enforcement and single-owner administrative controls
- Reentrancy protection through state-update ordering and immutable configuration
- Support for local and testnet deployments via script-based configuration

## Getting Started / Local Setup

### Prerequisites

- Foundry installed locally
- Node.js and npm are optional for tooling support, but Foundry is the primary dependency
- A wallet / RPC endpoint for any testnet or mainnet deployment

Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify the installation:

```bash
forge --version
```

### Clone and Set Up the Repository

```bash
git clone https://github.com/Drosophila360/CryptoQuest-Lottery.git
git checkout main
cd CryptoQuest-Lottery
forge install
```

### Build the Project

```bash
forge build
```

### Run Tests

```bash
forge test
```

For a filtered test run:

```bash
forge test --match-path test/*.t.sol
```

### Formatting and Documentation

Format Solidity files:

```bash
forge fmt
```

Generate NatSpec documentation:

```bash
forge doc
```

## Environment Variables & Deployment

The deployment scripts are designed to make network configuration explicit and repeatable.

Required values commonly include:

- `VRF_COORDINATOR`: Chainlink VRF coordinator address for the target network
- `LINK_TOKEN`: LINK token address for the target network
- `KEY_HASH`: gas lane / key hash used by VRF
- `SUBSCRIPTION_ID`: the Chainlink VRF subscription ID tied to the project
- `GAS_LIMIT`: max gas used for the VRF fulfillment callback
- `ENTRANCE_FEE`: raffle ticket price in wei
- `INTERVAL`: amount of time between raffle draws or upkeep windows

Local deployment scripts use Foundry cheatcodes and helper config patterns to set these values based on the selected chain. The `DeployRaffle.s.sol` script deploys the raffle contract, while `HelperConfig.s.sol` provides the chain-specific config and fallback values for local environment simulation.

Example deployment:

```bash
forge script script/DeployRaffle.s.sol
```

For a specific RPC or broadcast profile:
1. Import Your Private Key Into Foundry Keystore:
```bash
cast wallet import <KEYSTORE_NAME> --interactive
```
2. Configure your `.env` file:
Copy `.env.example` to `.env` and set your keystore name and address:
```env
SEPOLIA_RPC_URL=//https:eth-sepolia.g.alchemy.com/v2/<YOUR_ALCHEMY_KEY>
ETHERSCAN_API_KEY=<YOUR_ETHERSCAN_API_KEY>
```

3. Deploy using Makefile. Remember to update Makefile to match you details:
```bash
make deploy-raffles
```

```bash
forge script script/DeployRaffle.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

## Contract Reference / API

### `Raffles.sol`

The contract is the central raffle engine. It handles entrants, upkeep checks, VRF requests, winner selection, and payout distribution.

#### Core functions

- `enterRaffle()`: allows a user to enter by paying the configured entrance fee.
- `checkUpkeep(bytes memory)` or equivalent upkeep verification logic: monitors whether the raffle is ready for a draw.
- `performUpkeep(bytes memory)`: executes the draw request when conditions are met.
- `fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)`: receives the random values from VRF, selects the winner, and completes the raffle.

#### State variables

Typical internal state tracked by the raffle includes:

- entrant list / array of player addresses
- current raffle state (`OPEN`, `CALCULATING`, etc.)
- entrance fee
- recent winner
- last time stamp / interval tracking
- VRF request ID / gas lane / coordinator references
- raffle open/closed status

#### Custom errors

The contract uses custom errors for efficient and explicit revert conditions, for example:

- `Raffle__NotEnoughETHEntered()`
- `Raffle__TransferFailed()`
- `Raffle__SendMoreToEnterRaffle()`
- `Raffle__UpkeepNotNeeded()`
- `Raffle__RaffleNotOpen()`

The exact names may vary slightly based on contract version or updates in the codebase; refer to the actual Solidity source for the final list.

## Security & Best Practices

This project applies several production-grade security practices:

- Checks-Effects-Interactions (CEI): state changes are performed before any external calls, reducing reentrancy attack surfaces.
- Custom errors: gas-efficient and clearer than string-based revert messages.
- Explicit state validation: functions guard against invalid transitions, insufficient funds, and improper upkeep execution.
- Event-driven observability: important actions are emitted for off-chain monitoring and auditing.
- Automation gating: draw execution only occurs after the contract deems the raffle eligible.

The design intentionally separates validation, state mutations, and external calls to minimize risk and improve auditability.

## License & Credits

This project is distributed under an open-source license defined in the repository. Please refer to the repository's `LICENSE` file for exact terms.

Credits:

- Chainlink: VRF and Automation infrastructure
- Foundry: smart contract development and testing workflow
- OpenZeppelin: contract safety patterns and reusable standards

## Repository Notes

This README reflects the current implementation and configuration observed in the repository, including the Foundry-based workflow, Chainlink VRF v2.5 integration, deployment scripts, and the raffle state lifecycle.

For source-level details, refer to the following:

- `src/Raffles.sol` (main lottery contract)
- `script/DeployRaffle.s.sol` (deployment logic)
- `script/HelperConfig.s.sol` (chain config helper)
- `test/` (unit and integration tests)
- `foundry.toml` (build and test configuration)
