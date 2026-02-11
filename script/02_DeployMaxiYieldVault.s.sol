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

/**
 * @notice Script to deploy "Maxi Yield" Vault through the Deployer.
 * @dev Run with: forge script script/02_DeployMaxiYieldVault.s.sol --rpc-url <mantra_rpc> --broadcast --verify
 */
contract DeployMaxiYieldVault is Script {
    // Config for Mantra Testnet
    address public constant mUSD = 0x4B545d0758eda6601B051259bD977125fbdA7ba2;
    address public constant WETH = address(0);

    // Deployer and Auth addresses (deployed in step 01)
    address public deployerAddr = vm.envAddress("DEPLOYER_CONTRACT_ADDRESS");
    address public rolesAuthAddr = vm.envAddress("ROLES_AUTH_CONTRACT_ADDRESS");

    // Standard Project Roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;

    function run() external {
        vm.createSelectFork("mantra");
        uint256 deployerKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        address owner = vm.addr(deployerKey);
        Deployer deployer = Deployer(deployerAddr);
        RolesAuthority auth = RolesAuthority(rolesAuthAddr);

        vm.startBroadcast(deployerKey);

        // --- 1. Deploy Core Components via Deployer ---
        address vault = deployer.deployContract(
            "Maxi Yield Vault V1.0",
            type(BoringVault).creationCode,
            abi.encode(owner, "Maxi Yield mUSD", "my-mUSD", 6),
            0
        );

        address accountant = deployer.deployContract(
            "Maxi Yield Accountant V1.0",
            type(AccountantWithRateProviders).creationCode,
            abi.encode(
                owner,
                vault,
                owner,
                1e6,
                mUSD,
                1.5e4,
                0.5e4,
                20 hours,
                0,
                0
            ),
            0
        );

        address teller = deployer.deployContract(
            "Maxi Yield Teller V1.0",
            type(TellerWithMultiAssetSupport).creationCode,
            abi.encode(owner, vault, accountant, WETH),
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

        // Minter Role (2) -> Teller can mint shares
        auth.setRoleCapability(
            MINTER_ROLE,
            vault,
            BoringVault.enter.selector,
            true
        );
        auth.setUserRole(teller, MINTER_ROLE, true);

        // Burner Role (3) -> DelayedWithdraw can burn shares
        auth.setRoleCapability(
            BURNER_ROLE,
            vault,
            BoringVault.exit.selector,
            true
        );
        auth.setUserRole(delayedWithdraw, BURNER_ROLE, true);

        // Update Rate Role (11) -> Owner can update accountant exchange rate
        auth.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE,
            accountant,
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        auth.setUserRole(owner, UPDATE_EXCHANGE_RATE_ROLE, true);

        // Owner Role (8) -> Broad administrative rights
        auth.setRoleCapability(
            OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.setShareLockPeriod.selector,
            true
        );
        auth.setRoleCapability(
            OWNER_ROLE,
            teller,
            TellerWithMultiAssetSupport.updateAssetData.selector,
            true
        );
        auth.setRoleCapability(
            OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.setupWithdrawAsset.selector,
            true
        );
        auth.setRoleCapability(
            OWNER_ROLE,
            delayedWithdraw,
            DelayedWithdraw.setPullFundsFromVault.selector,
            true
        );
        auth.setUserRole(owner, OWNER_ROLE, true);

        // Public Roles
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
        TellerWithMultiAssetSupport(payable(teller)).setShareLockPeriod(86400); // 24h
        TellerWithMultiAssetSupport(payable(teller)).updateAssetData(
            ERC20(mUSD),
            true,
            true,
            0
        );

        DelayedWithdraw(delayedWithdraw).setupWithdrawAsset(
            ERC20(mUSD),
            0,
            7 days,
            0,
            100
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
