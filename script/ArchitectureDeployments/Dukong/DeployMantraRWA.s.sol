// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { DeployArcticArchitecture, ERC20, Deployer } from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import { AddressToBytes32Lib } from "src/helper/AddressToBytes32Lib.sol";
import { MantraAddresses } from "test/resources/MantraAddresses.sol";

// Import Decoder and Sanitizer to deploy.
import { RwaMockDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/RwaMockDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Dukong/DeployMantraRWA.s.sol:DeployMantraRWAScript --broadcast --slow --with-gas-price 60gwei --priority-gas-price 5gwei --verify --etherscan-api-key empty  
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployMantraRWAScript is DeployArcticArchitecture, MantraAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Test000 vault";
    string public boringVaultSymbol = "RWA";
    uint8 public boringVaultDecimals = 8;
    address public owner = dev0Address;

    function setUp() external {
        privateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork("mantra_dukong");
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = true;
        configureDeployment.setupRoles = true;
        configureDeployment.setupDepositAssets = true;
        configureDeployment.setupWithdrawAssets = true;
        configureDeployment.finishSetup = true;
        configureDeployment.setupTestUser = true;
        configureDeployment.saveDeploymentDetails = true;
        configureDeployment.deployerAddress = deployerAddress;
        configureDeployment.balancerVault = balancerVault;
        configureDeployment.WETH = address(WETH);

        // Save deployer.
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        // names.rolesAuthority = EtherFiBtcRolesAuthorityName;
        // names.lens = ArcticArchitectureLensName;
        // names.boringVault = EtherFiBtcName;
        // names.manager = EtherFiBtcManagerName;
        // names.accountant = EtherFiBtcAccountantName;
        // names.teller = EtherFiBtcTellerName;
        // names.rawDataDecoderAndSanitizer = EtherFiBtcDecoderAndSanitizerName;
        // names.delayedWithdrawer = EtherFiBtcDelayedWithdrawer;

        names.rolesAuthority = "Mantra RWA RolesAuthority Version 0.1";
        names.lens = ArcticArchitectureLensName;
        names.boringVault = "Mantra RWA WBTC V0.1";
        names.manager = "Mantra RWA WBTC Manager With Merkle Verification V0.1";
        names.accountant = "Mantra RWA WBTC Accountant With Rate Providers V0.1";
        names.teller = "Mantra RWA WBTC Teller With Multi Asset Support V0.0";
        names.rawDataDecoderAndSanitizer = "Mantra RWA WBTC Decoder and Sanitizer V0.1";
        names.delayedWithdrawer = "Mantra RWA WBTC Delayed Withdrawer V0.0";


        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = WBTC;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e18;
        //  4 decimals
        accountantParameters.platformFee = 0.02e4;
        accountantParameters.performanceFee = 0;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(RwaMockDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names.boringVault));

        // Setup extra deposit assets.
        depositAssets.push(
            DepositAsset({
                asset: WBTC,
                isPeggedToBase: true,
                rateProvider: address(0),
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );

        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: WBTC,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        bool allowPublicDeposits = true;
        bool allowPublicWithdraws = true;
        uint64 shareLockPeriod = 1 days;
        address delayedWithdrawFeeAddress = liquidPayoutAddress;

        vm.startBroadcast(privateKey);

        _deploy(
            "MantraRwaDeployment.json",
            owner,
            boringVaultName,
            boringVaultSymbol,
            boringVaultDecimals,
            creationCode,
            constructorArgs,
            delayedWithdrawFeeAddress,
            allowPublicDeposits,
            allowPublicWithdraws,
            shareLockPeriod,
            dev1Address
        );

        vm.stopBroadcast();
    }
}
