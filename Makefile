-include .env

.PHONY: deploy-raffles

install :; forge install cyfrin/foundry-devops && forge install smartcontractkit/chainlink-brownie-contracts && forge install foundry-rs/forge-std && forge install transmissions11/solmate

deploy-raffles:
	@forge script script/DeployRaffles.s.sol:DeployRaffles \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--account devAccount \
		--sender 0x802602c50f220BAc74354ee3Cf9A1e1C94c91803 \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

fund-subscription:
	@forge script script/Interactions.s.sol:FundSubscription \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--account devAccount \
		--sender 0x802602c50f220BAc74354ee3Cf9A1e1C94c91803 \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv		