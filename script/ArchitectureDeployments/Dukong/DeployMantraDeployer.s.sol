// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MantraAddresses} from "test/resources/MantraAddresses.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Dukong/DeployMantraDeployer.s.sol:DeployMantraDeployerScript --broadcast --etherscan-api-key empty --verify --slow
 * forge verify-contract --chain 5887 0x48499d6ccc57e9190a7523525a58bce28313ae06 --rpc-url https://evm.dukong.mantrachain.io --etherscan-api-key empty --verifier-url https://explorer.dukong.io/api
 * @dev Deploy the Deployer contract and RolesAuthority for Mantra Dukong network
 * @dev Note: Use --etherscan-api-key empty for Mantra Dukong verification
 */
contract DeployMantraDeployerScript is Script, ContractNames, MantraAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;

    uint8 public DEPLOYER_ROLE = 1;

    function setUp() external {
        privateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork("mantra_dukong");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        // Deploy the Deployer contract
        deployer = new Deployer(dev0Address, Authority(address(0)));
        
        // Log the deployed address
        console.log("Deployer deployed at:", address(deployer));


        // Deploy RolesAuthority using the Deployer
        creationCode = type(RolesAuthority).creationCode;
        constructorArgs = abi.encode(dev0Address, Authority(address(0)));
        rolesAuthority =
            RolesAuthority(deployer.deployContract(SevenSeasRolesAuthorityName, creationCode, constructorArgs, 0));

        // Set up the Deployer's authority
        deployer.setAuthority(rolesAuthority);

        // Grant deployer role capabilities
        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.deployContract.selector, true);
        
        // Grant deployer role to dev addresses
        rolesAuthority.setUserRole(dev0Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev1Address, DEPLOYER_ROLE, true);

        console.log("Deployment complete!");
        console.log("Deployer:", address(deployer));
        console.log("RolesAuthority:", address(rolesAuthority));

        vm.stopBroadcast();
    }
}

