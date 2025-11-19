// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MantraAddresses} from "test/resources/MantraAddresses.sol";
import {RwaMock} from "src/mock/RwaMock.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Dukong/DeployMantraMockRWA.s.sol:DeployMantraMockRwaScript --broadcast --etherscan-api-key empty --verify --slow
 *  source .env && forge script script/ArchitectureDeployments/Dukong/DeployMantraMockRWA.s.sol:DeployMantraMockRwaScript --broadcast --etherscan-api-key empty --verify --slow --with-gas-price 60gwei --priority-gas-price 5gwei
 * @dev Deploy the Deployer contract and RolesAuthority for Mantra Dukong network
 * @dev Note: Use --etherscan-api-key empty for Mantra Dukong verification
 */
contract DeployMantraMockRwaScript is Script, ContractNames, MantraAddresses {
    uint256 public privateKey;

    Deployer public deployer;

    // Contracts to deploy
    RwaMock public rawMock;

    function setUp() external {
        privateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork("mantra_dukong");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);


        // Deploy the Deployer contract
        deployer = Deployer(0xDF24A4CD0932aEBe4c3B7a0A12a36F37bcB42ff9);
        vm.sleep(3);

        // Deploy RolesAuthority using the Deployer
        creationCode = type(RwaMock).creationCode;
        constructorArgs = abi.encode(0x2A8E20Ba7aB3C3A90527EF0d2d970fd22f7C25AB);

        rawMock =
            RwaMock(deployer.deployContract("RwaMock", creationCode, constructorArgs, 0));

        console.log("Deployment complete!");
        console.log("RwaMock:", address(rawMock));

        vm.stopBroadcast();
    }
}

