-include .env

help:
	@echo "Usage: make <target>"

all: install build

install:
	@forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts --no-commit && forge install cyfrin/foundry-devops --no-commit && forge install smartcontractkit/chainlink-local --no-commit

build :; @forge build

snapshot :; @forge snapshot

# deployment script 

deploy-checkBalance:
	@forge script script/DeployCheckBalance.s.sol:DeployCheckBalance --rpc-url $(AMOY_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast --verify --etherscan-api-key ${AMOYSCAN_API_KEY} -vvvv

deploy-sender:
	@forge script script/DeploySender.s.sol:DeploySender --rpc-url $(AMOY_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast --verify --etherscan-api-key ${AMOYSCAN_API_KEY} -vvvv

deploy-subscription:
	@forge script script/DeploySubscription.s.sol:DeploySubscription --rpc-url $(AMOY_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast --verify --etherscan-api-key ${AMOYSCAN_API_KEY} -vvvv

deploy-receiver:
	@forge script script/DeployReceiver.s.sol:DeployReceiver --rpc-url $(SEPOLIA_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast --verify --verifier blockscout --verifier-url https://eth-sepolia.blockscout.com/api/ -vvvv

deploy-relayer:
	@forge script script/DeployRelayer.s.sol:DeployRelayer --rpc-url $(SEPOLIA_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast --verify --verifier blockscout --verifier-url https://eth-sepolia.blockscout.com/api/ -vvvv

# interactions script 

add-consumer:
	@forge script script/AddConsumer.s.sol:AddConsumer --rpc-url $(AMOY_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvvv

send-requestToGetBalance:
	@forge script script/SendRequestToGetBalance.s.sol:SendRequestToGetBalance --rpc-url $(AMOY_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvv

get-balance:
	@forge script script/GetBalance.s.sol:GetBalance --rpc-url $(AMOY_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvv

add-linkTokenToReceiver:
	@forge script script/AddLinkTokenToReceiver.s.sol:AddLinkTokenToReceiver --rpc-url $(SEPOLIA_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvv

add-linkTokenToRelayer:
	@forge script script/AddLinkTokenToRelayer.s.sol:AddLinkTokenToRelayer --rpc-url $(SEPOLIA_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvv

add-linkTokenToSender:
	@forge script script/AddLinkTokenToSender.s.sol:AddLinkTokenToSender --rpc-url $(AMOY_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvv	

approve-receiverToSpendCCIPBNM:
	@forge script script/ApproveReceiverToSpendCCIPBNM.s.sol:ApproveReceiverToSpendCCIPBNM --rpc-url $(SEPOLIA_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvv

pay-subscriptionFeeforOptionalChain:
	@forge script script/PaySubscriptionFeeForOptionalChain.s.sol:PaySubscriptionFeeForOptionalChain --rpc-url $(AMOY_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvv

get-signedMessage:
	@forge script script/GetSignedMessage.s.sol:GetSignedMessage --rpc-url $(SEPOLIA_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvv

transfer-ownershipToSubscription:
	@forge script script/TransferOwnershipToSubscription.s.sol:TransferOwnershipToSubscription --rpc-url $(AMOY_RPC_URL) --account burner --sender 0xFB6a372F2F51a002b390D18693075157A459641F --broadcast -vvvv

# Audit

slither:
	@slither . --config-file slither.config.json

aderyn:
	@aderyn .