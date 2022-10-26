source .env

export RPC_URL=$RPC_URL
export PRIVATE_KEY=$PRIVATE_KEY
export ETHERSCAN_KEY=$ETHERSCAN_KEY

forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/TinyBondsFactory.sol:TinyBondsFactory --etherscan-api-key $ETHERSCAN_KEY --verify