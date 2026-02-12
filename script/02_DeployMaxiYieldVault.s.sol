// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {
    AccountantWithRateProviders
} from "src/base/Roles/AccountantWithRateProviders.sol";
import {
    TellerWithMultiAssetSupport
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {DelayedWithdraw} from "src/base/Roles/DelayedWithdraw.sol";
import {
    RolesAuthority,
    Authority
} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import "forge-std/Script.sol";
import {
    MantraMainnetConstants as Constants
} from "./MantraMainnetConstants.sol";

contract DeployMaxiYieldVault is Script {
    address public deployerAddr = vm.envAddress("DEPLOYER_CONTRACT_ADDRESS");
    address public rolesAuthAddr = vm.envAddress("ROLES_AUTH_CONTRACT_ADDRESS");

    function run() external {
        vm.createSelectFork("mantra");
        uint256 deployerKey = vm.envUint("MANTRA_DEPLOYER");
        address owner = vm.addr(deployerKey);
        Deployer deployer = Deployer(deployerAddr);
        RolesAuthority auth = RolesAuthority(rolesAuthAddr);

        vm.startBroadcast(deployerKey);

        // --- 1. Deploy Core Components ---
        address vault = deployer.deployContract(
            Constants.MAXI_NAME,
            type(BoringVault).creationCode,
            abi.encode(
                owner,
                Constants.MAXI_TOKEN_NAME,
                Constants.MAXI_SYMBOL,
                Constants.MAXI_DECIMALS
            ),
            0
        );

        address accountant = deployer.deployContract(
            "Maxi Yield Accountant V1.0",
            type(AccountantWithRateProviders).creationCode,
            abi.encode(
                owner, // owner
                vault, // vault
                owner, // payoutAddress
                Constants.ACCOUNTANT_STARTING_EXCHANGE_RATE, // startingExchangeRate
                Constants.mUSD, // base
                Constants.ACCOUNTANT_ALLOWED_EXCHANGE_RATE_CHANGE_UPPER,
                Constants.ACCOUNTANT_ALLOWED_EXCHANGE_RATE_CHANGE_LOWER,
                Constants.ACCOUNTANT_MINIMUM_UPDATE_DELAY,
                Constants.ACCOUNTANT_PLATFORM_FEE,
                Constants.ACCOUNTANT_PERFORMANCE_FEE
            ),
            0
        );

        address teller = deployer.deployContract(
            "Maxi Yield Teller V1.0",
            type(TellerWithMultiAssetSupport).creationCode,
            abi.encode(owner, vault, accountant, Constants.WETH),
            0
        );

        address delayedWithdraw = deployer.deployContract(
            "Maxi Yield DelayedWithdraw V1.0",
            type(DelayedWithdraw).creationCode,
            abi.encode(owner, vault, accountant, owner),
            0
        );

        // --- 2. Post-Deployment Setup ---

        // Roles Permissions
        BoringVault(payable(vault)).setAuthority(auth);
        AccountantWithRateProviders(accountant).setAuthority(auth);
        TellerWithMultiAssetSupport(payable(teller)).setAuthority(auth);
        DelayedWithdraw(delayedWithdraw).setAuthority(auth);

        // Grant Roles
        auth.setRoleCapability(
            Constants.MINTER_ROLE,
            vault,
            BoringVault.enter.selector,
            true
        );
        auth.setUserRole(teller, Constants.MINTER_ROLE, true);

        auth.setRoleCapability(
            Constants.BURNER_ROLE,
            vault,
            BoringVault.exit.selector,
            true
        );
        auth.setUserRole(delayedWithdraw, Constants.BURNER_ROLE, true);

        auth.setRoleCapability(
            Constants.UPDATE_EXCHANGE_RATE_ROLE,
            accountant,
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        auth.setUserRole(owner, Constants.UPDATE_EXCHANGE_RATE_ROLE, true);

        // Owner Roles
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.setShareLockPeriod.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.updateAssetData.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.setupWithdrawAsset.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.setPullFundsFromVault.selector,
            true
        );
        auth.setUserRole(owner, Constants.OWNER_ROLE, true);

        // Public Capabilities
        auth.setPublicCapability(
            teller,
            TellerWithMultiAssetSupport.deposit.selector,
            true
        );
        auth.setPublicCapability(
            delayedWithdraw,
            DelayedWithdraw.requestWithdraw.selector,
            true
        );
        auth.setPublicCapability(
            delayedWithdraw,
            DelayedWithdraw.completeWithdraw.selector,
            true
        );

        // Logic Config
        TellerWithMultiAssetSupport(payable(teller)).setShareLockPeriod(
            Constants.TELLER_SHARE_LOCK_PERIOD
        );
        TellerWithMultiAssetSupport(payable(teller)).updateAssetData(
            ERC20(Constants.mUSD),
            true,
            true,
            0
        );

        DelayedWithdraw(delayedWithdraw).setupWithdrawAsset(
            ERC20(Constants.mUSD),
            Constants.DW_WITHDRAW_DELAY,
            Constants.DW_COMPLETION_WINDOW,
            Constants.DW_WITHDRAW_FEE,
            Constants.DW_MAX_LOSS
        );
        DelayedWithdraw(delayedWithdraw).setPullFundsFromVault(true);

        BoringVault(payable(vault)).setBeforeTransferHook(teller);

        vm.stopBroadcast();

        console.log("Maxi Yield Vault:", vault);
        console.log("Maxi Yield Accountant:", accountant);
        console.log("Maxi Yield Teller:", teller);
        console.log("Maxi Yield DelayedWithdraw:", delayedWithdraw);
    }
}
