-include .env

.PHONY: remove install deploy-raffles deploy-raffles-sepolia

DEFAULT_ANVIL_KEY := 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
ACCOUNT ?= devAccount
SEPOLIA_SENDER ?= 0x802602c50f220BAc74354ee3Cf9A1e1C94c91803

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# Install modules
install :; forge install cyfrin/foundry-devops && forge install smartcontractkit/chainlink-brownie-contracts && forge install foundry-rs/forge-std && forge install transmissions11/solmate

# Local deployment-anvil
deploy-raffles:
	@cast rpc anvil_mine 0x1 --rpc-url http://localhost:8545 >/dev/null
	@forge script script/DeployRaffles.s.sol:DeployRaffles \
	--rpc-url http://localhost:8545 \
	--private-key $(DEFAULT_ANVIL_KEY) \
	--broadcast \
	-vvvv

# Deploy to Sepolia testnet
deploy-raffles-sepolia:
	@forge script script/DeployRaffles.s.sol:DeployRaffles \
	--rpc-url sepolia \
	--account $(ACCOUNT) \
	--sender $(SEPOLIA_SENDER) \
	--gas-estimate-multiplier 800 \
	--slow \
	--broadcast \
	--verify \
	--etherscan-api-key sepolia \
	-vvvv
