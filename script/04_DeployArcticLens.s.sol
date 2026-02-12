// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {Deployer} from "src/helper/Deployer.sol";
import "forge-std/Script.sol";
import {MantraConstants as Constants} from "./00_MantraConstants.sol";

contract DeployArcticLens is Script {
    address public deployerAddr = vm.envAddress("DEPLOYER_CONTRACT_ADDRESS");

    function run() external {
        vm.createSelectFork("mantra");
        uint256 deployerKey = vm.envUint("MANTRA_DEPLOYER");
        Deployer deployer = Deployer(deployerAddr);

        vm.startBroadcast(deployerKey);

        // Deploy Lens via Deployer using Constants name
        address lens = deployer.deployContract(
            Constants.ARCTIC_LENS_NAME,
            type(ArcticArchitectureLens).creationCode,
            hex"",
            0
        );

        vm.stopBroadcast();

        console.log("Lens deployed at:", lens);
    }
}
