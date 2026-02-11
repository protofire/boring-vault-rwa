// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {Deployer} from "src/helper/Deployer.sol";
import "forge-std/Script.sol";

/**
 * @notice Script to deploy ArcticArchitectureLens through the Deployer.
 * @dev Run with: forge script script/04_DeployArcticLens.s.sol --rpc-url <mantra_rpc> --broadcast --verify
 */
contract DeployArcticLens is Script {
    // Deployer address (deployed in step 01)
    address public deployerAddr = vm.envAddress("DEPLOYER_CONTRACT_ADDRESS");

    function run() external {
        vm.createSelectFork("mantra");
        uint256 deployerKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        Deployer deployer = Deployer(deployerAddr);

        vm.startBroadcast(deployerKey);

        // Deploy Lens via Deployer
        address lens = deployer.deployContract(
            "Arctic Architecture Lens V1.0",
            type(ArcticArchitectureLens).creationCode,
            hex"",
            0
        );

        vm.stopBroadcast();

        console.log("ArcticArchitectureLens deployed at:", lens);
    }
}
