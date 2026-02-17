// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {
    AccountantWithRateProviders
} from "src/base/Roles/AccountantWithRateProviders.sol";
import {
    AccountantWithFixedRate
} from "src/base/Roles/AccountantWithFixedRate.sol";
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
import {MantraConstants as Constants} from "./00_MantraConstants.sol";

contract DeployPointsVault is Script {
    address public deployerAddr = vm.envAddress("DEPLOYER_CONTRACT_ADDRESS");
    address public rolesAuthAddr = vm.envAddress("ROLES_AUTH_CONTRACT_ADDRESS");

    function run() external {
        vm.createSelectFork("mantra");
        uint256 deployerKey = vm.envUint("MANTRA_DEPLOYER");
        address owner = vm.addr(deployerKey);

        // Environment Toggle
        bool isMainnet = vm.envOr("MANTRA_MAINNET", false);
        address mUSD = isMainnet
            ? Constants.mUSD_MAINNET
            : Constants.mUSD_TESTNET;
        address WETH = isMainnet
            ? Constants.WETH_MAINNET
            : Constants.WETH_TESTNET;

        Deployer deployer = Deployer(deployerAddr);
        RolesAuthority auth = RolesAuthority(rolesAuthAddr);

        vm.startBroadcast(deployerKey);

        // --- 1. Deploy Core Components ---
        address vault = deployer.deployContract(
            Constants.POINTS_VAULT_NAME,
            type(BoringVault).creationCode,
            abi.encode(
                owner,
                Constants.POINTS_TOKEN_NAME,
                Constants.POINTS_SYMBOL,
                Constants.POINTS_DECIMALS
            ),
            0
        );

        address accountant = deployer.deployContract(
            Constants.POINTS_ACCOUNTANT_NAME,
            type(AccountantWithFixedRate).creationCode,
            abi.encode(
                owner, // owner
                vault, // vault
                owner, // payoutAddress
                Constants.ACCOUNTANT_STARTING_EXCHANGE_RATE, // startingExchangeRate
                mUSD, // base (Dynamic)
                Constants.ACCOUNTANT_ALLOWED_EXCHANGE_RATE_CHANGE_UPPER,
                Constants.ACCOUNTANT_ALLOWED_EXCHANGE_RATE_CHANGE_LOWER,
                Constants.ACCOUNTANT_MINIMUM_UPDATE_DELAY,
                Constants.ACCOUNTANT_PLATFORM_FEE,
                Constants.ACCOUNTANT_PERFORMANCE_FEE
            ),
            0
        );

        address teller = deployer.deployContract(
            Constants.POINTS_TELLER_NAME,
            type(TellerWithMultiAssetSupport).creationCode,
            abi.encode(owner, vault, accountant, WETH), // WETH (Dynamic)
            0
        );

        address delayedWithdraw = deployer.deployContract(
            Constants.POINTS_DW_NAME,
            type(DelayedWithdraw).creationCode,
            abi.encode(owner, vault, accountant, owner),
            0
        );

        // --- 2. Post-Deployment Setup ---

        // Roles Permissions
        BoringVault(payable(vault)).setAuthority(auth);
        AccountantWithFixedRate(accountant).setAuthority(auth);
        TellerWithMultiAssetSupport(payable(teller)).setAuthority(auth);
        DelayedWithdraw(delayedWithdraw).setAuthority(auth);

        // --- Role Configuration ---
        address rateUpdater = isMainnet
            ? Constants.RATE_UPDATER_MAINNET
            : Constants.RATE_UPDATER_TESTNET;
        address manager = isMainnet
            ? Constants.MANAGER_MAINNET
            : Constants.MANAGER_TESTNET;

        // Fallback to Owner if not set (for safety/testing)
        if (rateUpdater == address(0)) rateUpdater = owner;
        if (manager == address(0)) manager = owner;

        // Grant Roles

        // MINTER_ROLE (Teller)
        auth.setRoleCapability(
            Constants.MINTER_ROLE,
            vault,
            BoringVault.enter.selector,
            true
        );
        auth.setUserRole(teller, Constants.MINTER_ROLE, true);

        // BURNER_ROLE (DelayedWithdraw, BoringVault)
        auth.setRoleCapability(
            Constants.BURNER_ROLE,
            vault,
            BoringVault.exit.selector,
            true
        );
        auth.setUserRole(delayedWithdraw, Constants.BURNER_ROLE, true);

        // UPDATE_EXCHANGE_RATE_ROLE (Rate Updater)
        auth.setRoleCapability(
            Constants.UPDATE_EXCHANGE_RATE_ROLE,
            accountant,
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        auth.setUserRole(
            rateUpdater,
            Constants.UPDATE_EXCHANGE_RATE_ROLE,
            true
        );

        // MANAGER_ROLE (Manager)
        auth.setUserRole(manager, Constants.MANAGER_ROLE, true);

        // OWNER_ROLE (Owner - kept as deployer/owner for now)
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
            ERC20(mUSD),
            true,
            true,
            0
        );

        DelayedWithdraw(delayedWithdraw).setupWithdrawAsset(
            ERC20(mUSD),
            Constants.DW_WITHDRAW_DELAY,
            Constants.DW_COMPLETION_WINDOW,
            Constants.DW_WITHDRAW_FEE,
            Constants.DW_MAX_LOSS
        );
        DelayedWithdraw(delayedWithdraw).setPullFundsFromVault(true);

        BoringVault(payable(vault)).setBeforeTransferHook(teller);

        // --- Ownership Transfer ---
        // 1. Identify Target Owner
        address mantraOwner = vm.envOr("MANTRA_OWNER", address(0));
        if (mantraOwner == address(0)) {
            mantraOwner = isMainnet
                ? Constants.OWNER_MAINNET
                : Constants.OWNER_TESTNET;
        }

        // 2. Perform Transfer if valid and different from deployer
        if (mantraOwner != address(0) && mantraOwner != owner) {
            console.log("Transferring ownership to:", mantraOwner);

            // Grant OWNER_ROLE to new owner first
            if (!auth.doesUserHaveRole(mantraOwner, Constants.OWNER_ROLE)) {
                auth.setUserRole(mantraOwner, Constants.OWNER_ROLE, true);
            }

            // Transfer Auth Ownership of components
            if (BoringVault(payable(vault)).owner() != mantraOwner)
                BoringVault(payable(vault)).transferOwnership(mantraOwner);
            if (AccountantWithFixedRate(accountant).owner() != mantraOwner)
                AccountantWithFixedRate(accountant).transferOwnership(
                    mantraOwner
                );
            if (
                TellerWithMultiAssetSupport(payable(teller)).owner() !=
                mantraOwner
            )
                TellerWithMultiAssetSupport(payable(teller)).transferOwnership(
                    mantraOwner
                );
            if (DelayedWithdraw(delayedWithdraw).owner() != mantraOwner)
                DelayedWithdraw(delayedWithdraw).transferOwnership(mantraOwner);

            // Revoke Roles from Deployer
            if (auth.doesUserHaveRole(owner, Constants.OWNER_ROLE)) {
                auth.setUserRole(owner, Constants.OWNER_ROLE, false);
                console.log("Revoked OWNER_ROLE from deployer");
            }
        }

        vm.stopBroadcast();

        console.log("Environment:", isMainnet ? "Mainnet" : "Testnet");
        console.log("Points Vault:", vault);
        console.log("Points Accountant (Fixed):", accountant);
        console.log("Points Teller:", teller);
        console.log("Points DelayedWithdraw:", delayedWithdraw);
    }
}
