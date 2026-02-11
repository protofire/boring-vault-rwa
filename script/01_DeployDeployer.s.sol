// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {
    RolesAuthority,
    Authority
} from "@solmate/auth/authorities/RolesAuthority.sol";
import "forge-std/Script.sol";

/**
 * @notice Script to deploy the CREATE3 Deployer and its RolesAuthority.
 * @dev Run with: forge script script/01_DeployDeployer.s.sol --rpc-url <mantra_rpc> --broadcast --verify
 */
contract DeployDeployer is Script {
    uint8 public constant DEPLOYER_ROLE = 1;

    function run() external {
        uint256 deployerKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address deployerAddr = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1. Deploy Deployer (Owned by deployerAddr, no initial authority)
        Deployer deployer = new Deployer(deployerAddr, Authority(address(0)));

        // 2. Deploy RolesAuthority for the Deployer (Owned by deployerAddr)
        RolesAuthority auth = new RolesAuthority(
            deployerAddr,
            Authority(address(0))
        );

        // 3. Link them
        deployer.setAuthority(auth);

        // 4. Grant deployerAddr permission to deploy through the factory
        // We use Role 1 for Deployer Role to match the project's standard
        auth.setRoleCapability(
            DEPLOYER_ROLE,
            address(deployer),
            Deployer.deployContract.selector,
            true
        );
        auth.setUserRole(deployerAddr, DEPLOYER_ROLE, true);

        vm.stopBroadcast();

        console.log("Deployer deployed at:", address(deployer));
        console.log("RolesAuthority deployed at:", address(auth));
    }
}
