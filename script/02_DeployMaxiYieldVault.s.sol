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
import {MantraConstants as Constants} from "./00_MantraConstants.sol";

contract DeployMaxiYieldVault is Script {
    address public deployerAddr = vm.envAddress("DEPLOYER_CONTRACT_ADDRESS");
    address public rolesAuthAddr = vm.envAddress("ROLES_AUTH_CONTRACT_ADDRESS");

    // forge script script/02_DeployMaxiYieldVault.s.sol \
    //   --rpc-url mantra_dukong \
    //   --broadcast \
    //   --chain-id 5887 \
    //   --legacy \
    //   --skip-simulation \
    //   -vvvv

    function run() external {
        string memory forkName = vm.envOr("MANTRA_MAINNET", false)
            ? "mantra"
            : "mantra_dukong";
        vm.createSelectFork(forkName);
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
            Constants.RFR_VAULT_NAME,
            type(BoringVault).creationCode,
            abi.encode(
                owner,
                Constants.RFR_TOKEN_NAME,
                Constants.RFR_SYMBOL,
                Constants.RFR_DECIMALS
            ),
            0
        );

        address accountant = deployer.deployContract(
            Constants.RFR_ACCOUNTANT_NAME,
            type(AccountantWithRateProviders).creationCode,
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
            Constants.RFR_TELLER_NAME,
            type(TellerWithMultiAssetSupport).creationCode,
            abi.encode(owner, vault, accountant, WETH), // WETH (Dynamic)
            0
        );

        address delayedWithdraw = deployer.deployContract(
            Constants.RFR_DW_NAME,
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
        // exit.selector allows DW to burn shares and trigger the Vault to send underlying assets directly to the user
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

        // --- OWNER_ROLE Maintenance & Fees ---
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.changeWithdrawFee.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.changeWithdrawDelay.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.changeCompletionWindow.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.changeMaxLoss.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.stopWithdrawalsInAsset.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.setFeeAddress.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            accountant,
            AccountantWithRateProviders.updatePlatformFee.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            accountant,
            AccountantWithRateProviders.updatePerformanceFee.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            accountant,
            AccountantWithRateProviders.updatePayoutAddress.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            accountant,
            AccountantWithRateProviders.updateDelay.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            accountant,
            AccountantWithRateProviders.updateUpper.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            accountant,
            AccountantWithRateProviders.updateLower.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            accountant,
            AccountantWithRateProviders.pause.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            accountant,
            AccountantWithRateProviders.unpause.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            accountant,
            AccountantWithRateProviders.resetHighwaterMark.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.pause.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.unpause.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.denyAll.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.allowAll.selector,
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
            teller,
            TellerWithMultiAssetSupport.depositWithPermit.selector,
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
            true, // isSupported
            true, // isDepositAsset
            0 // sharePremium
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
            if (AccountantWithRateProviders(accountant).owner() != mantraOwner)
                AccountantWithRateProviders(accountant).transferOwnership(
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
            // if (auth.doesUserHaveRole(owner, Constants.OWNER_ROLE)) {
            //     auth.setUserRole(owner, Constants.OWNER_ROLE, false);
            //     console.log("Revoked OWNER_ROLE from deployer");
            // }
        }

        vm.stopBroadcast();

        console.log("Environment:", isMainnet ? "Mainnet" : "Testnet");
        console.log("Yield Vault:", vault);
        console.log("Yield Accountant:", accountant);
        console.log("Yield Teller:", teller);
        console.log("Yield DelayedWithdraw:", delayedWithdraw);
    }
}
