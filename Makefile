-include .env

.PHONY: deploy-raffles

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