#!/bin/bash

# Configuration
RPC_URL="mantra_dukong"
VERIFIER="blockscout"
VERIFIER_URL="https://explorer.dukong.io/api"

# Deployed Addresses
DEPLOYER="0xa54DD6f938EB7C6394BF10B06E267f10aA3fE2eF"
ROLES_AUTHORITY="0x921b20e49ec45B3441CF45e2BeccBEF33620AeE6"
LENS="0x0FDCf61ed820a7e323f74D83B0A2302beD5e29E0"

# Owner (retrieved from broadcast logs)
OWNER="0x37723e376FdF70854665B5f1a5C49cB30E1691AC"

echo "Verifying Deployer..."
forge verify-contract $DEPLOYER src/helper/Deployer.sol:Deployer \
    --constructor-args $(cast abi-encode "constructor(address,address)" $OWNER 0x0000000000000000000000000000000000000000) \
    --rpc-url $RPC_URL \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

echo "Verifying RolesAuthority..."
forge verify-contract $ROLES_AUTHORITY lib/solmate/src/auth/authorities/RolesAuthority.sol:RolesAuthority \
    --constructor-args $(cast abi-encode "constructor(address,address)" $OWNER 0x0000000000000000000000000000000000000000) \
    --rpc-url $RPC_URL \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

echo "Verifying ArcticArchitectureLens..."
forge verify-contract $LENS src/helper/ArcticArchitectureLens.sol:ArcticArchitectureLens \
    --rpc-url $RPC_URL \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL
