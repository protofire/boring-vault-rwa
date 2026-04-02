// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {
    RolesAuthority,
    Authority
} from "@solmate/auth/authorities/RolesAuthority.sol";
import "forge-std/Script.sol";
import {MantraConstants as Constants} from "./00_MantraConstants.sol";

// forge script script/01_DeployDeployer.s.sol --rpc-url mantra_dukong --broadcast --slow

contract DeployDeployer is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("MANTRA_DEPLOYER");
        address deployerAddr = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1. Deploy Deployer
        Deployer deployer = new Deployer(deployerAddr, Authority(address(0)));

        // 2. Deploy RolesAuthority
        RolesAuthority auth = new RolesAuthority(
            deployerAddr,
            Authority(address(0))
        );

        // 3. Link them
        deployer.setAuthority(auth);

        // 4. Grant permissions
        auth.setRoleCapability(
            Constants.DEPLOYER_ROLE,
            address(deployer),
            Deployer.deployContract.selector,
            true
        );
        auth.setUserRole(deployerAddr, Constants.DEPLOYER_ROLE, true);

        vm.stopBroadcast();

        console.log("Deployer deployed at:", address(deployer));
        console.log("RolesAuthority deployed at:", address(auth));
    }
}
