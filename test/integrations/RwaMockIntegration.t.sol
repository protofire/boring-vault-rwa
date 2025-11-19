// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {AccountantWithRateProviders, IRateProvider} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {DelayedWithdraw} from "src/base/Roles/DelayedWithdraw.sol";
import {RwaMock} from "src/mock/RwaMock.sol";
import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {MintableERC20} from "src/mock/MintableERC20.sol";
import {RwaMockDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RwaMockDecoderAndSanitizer.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {WETH} from "@solmate/tokens/WETH.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract RwaMockIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    // Contracts
    MintableERC20 public WBTC;
    Deployer public deployer;
    RolesAuthority public rolesAuthority;
    RwaMock public rwaMock;
    BoringVault public boringVault;
    ManagerWithMerkleVerification public manager;
    AccountantWithRateProviders public accountant;
    TellerWithMultiAssetSupport public teller;
    RwaMockDecoderAndSanitizer public decoderAndSanitizer;
    DelayedWithdraw public delayedWithdrawer;
    WETH public weth;
    ArcticArchitectureLens public lens;


    // Roles
    uint8 public constant DEPLOYER_ROLE = 1;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    uint8 public constant BORING_VAULT_ROLE = 5;

    // Test addresses
    address public owner;
    address public alice;
    address public strategist;
    address public feeRecipient;

    // Test constants
    uint256 public constant INITIAL_DEPOSIT = 100 * 10**18; // 100 WBTC (18 decimals)
    uint256 public constant PROFIT_AMOUNT = 10 * 10**18; // 10 WBTC profit
    uint256 public constant ONE_SHARE = 10**18; // 1 share (18 decimals)

    // State variables to avoid stack too deep
    uint256 public aliceShares;
    uint256 public rwaMockShares;
    uint96 public initialExchangeRate;
    uint96 public newExchangeRate;

    function setUp() external {
        // Create test addresses
        owner = address(this);
        alice = vm.addr(1);
        strategist = vm.addr(2);
        feeRecipient = vm.addr(3);

        // Deploy WETH (needed for Teller)
        weth = new WETH();

        // Deploy mintable mock token
        WBTC = new MintableERC20();

        // Deploy Deployer
        deployer = new Deployer(owner, Authority(address(0)));

        // Deploy RolesAuthority using Deployer
        bytes memory creationCode = type(RolesAuthority).creationCode;
        bytes memory constructorArgs = abi.encode(owner, Authority(address(0)));
        rolesAuthority = RolesAuthority(
            deployer.deployContract("Test RolesAuthority", creationCode, constructorArgs, 0)
        );

        // Set up Deployer's authority
        deployer.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.deployContract.selector, true);
        rolesAuthority.setUserRole(owner, DEPLOYER_ROLE, true);

        // Deploy RwaMock using Deployer
        creationCode = type(RwaMock).creationCode;
        constructorArgs = abi.encode(WBTC);
        rwaMock = RwaMock(deployer.deployContract("RwaMock", creationCode, constructorArgs, 0));

        // Deploy BoringVault using Deployer
        creationCode = type(BoringVault).creationCode;
        constructorArgs = abi.encode(owner, "Test RWA Vault", "RWA", 18);
        boringVault = BoringVault(payable(deployer.deployContract("Test BoringVault", creationCode, constructorArgs, 0)));

        // Deploy Manager
        creationCode = type(ManagerWithMerkleVerification).creationCode;
        constructorArgs = abi.encode(owner, address(boringVault), address(0)); // No balancer vault for test
        manager = ManagerWithMerkleVerification(
            deployer.deployContract("Test Manager", creationCode, constructorArgs, 0)
        );

        // Deploy Accountant
        creationCode = type(AccountantWithRateProviders).creationCode;
        constructorArgs = abi.encode(
            owner,
            address(boringVault),
            feeRecipient,
            1e18, // startingExchangeRate
            address(WBTC), // base
            1.2e4, // allowedExchangeRateChangeUpper (20% to allow for profit scenarios)
            0.995e4, // allowedExchangeRateChangeLower
            1 days / 4, // minimumUpdateDelayInSeconds
            0.02e4, // platformFee
            0 // performanceFee
        );
        accountant = AccountantWithRateProviders(
            deployer.deployContract("Test Accountant", creationCode, constructorArgs, 0)
        );

        // Deploy Teller
        creationCode = type(TellerWithMultiAssetSupport).creationCode;
        constructorArgs = abi.encode(owner, address(boringVault), address(accountant), address(weth));
        teller = TellerWithMultiAssetSupport(
            deployer.deployContract("Test Teller", creationCode, constructorArgs, 0)
        );

        // Deploy Decoder and Sanitizer
        decoderAndSanitizer = new RwaMockDecoderAndSanitizer(address(boringVault));

        // Deploy DelayedWithdraw
        creationCode = type(DelayedWithdraw).creationCode;
        constructorArgs = abi.encode(owner, address(boringVault), address(accountant), feeRecipient);
        delayedWithdrawer = DelayedWithdraw(
            deployer.deployContract("Test DelayedWithdraw", creationCode, constructorArgs, 0)
        );

        // Deploy Lens
        creationCode = type(ArcticArchitectureLens).creationCode;
        lens = ArcticArchitectureLens(deployer.deployContract("Test Lens", creationCode, hex"", 0));

        // Set authorities
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        delayedWithdrawer.setAuthority(rolesAuthority);

        // Setup roles and capabilities
        _setupRoles();

        // Setup deposit asset in Teller
        teller.updateAssetData(WBTC, true, false, 0); // asset, allowDeposits, allowWithdraws, no premium

        // Setup withdraw asset in DelayedWithdraw
        delayedWithdrawer.setupWithdrawAsset(WBTC, 3 days, 7 days, 0, 0.01e4); // asset, delay, window, fee, maxLoss
        // Set pull funds from vault
        delayedWithdrawer.setPullFundsFromVault(true);
       
        // Setup rate provider in Accountant (WBTC is pegged to base)
        accountant.setRateProviderData(WBTC, true, address(0));
       
    }

    function _setupRoles() internal {
        // BoringVault roles
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(delayedWithdrawer), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);

        // Manager roles
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setUserRole(strategist, STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(owner, OWNER_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);

        // Accountant roles
        rolesAuthority.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE,
            address(accountant),
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE,
            address(accountant),
            AccountantWithRateProviders.unpause.selector,
            true
        );
        rolesAuthority.setUserRole(strategist, UPDATE_EXCHANGE_RATE_ROLE, true);
        rolesAuthority.setUserRole(owner, MULTISIG_ROLE, true);

        // Teller roles - allow public deposits
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);

        // DelayedWithdraw roles
        rolesAuthority.setPublicCapability(address(delayedWithdrawer), DelayedWithdraw.requestWithdraw.selector, true);
        rolesAuthority.setPublicCapability(address(delayedWithdrawer), DelayedWithdraw.completeWithdraw.selector, true);
    }

    function testCompleteFlowWithProfit() external {
        _step1_AliceDeposits();
        _step2_ManagerInvestsToRwaMock();
        _step3_ManagerUpdatesInitialExchangeRate();
        _step4_ManagerAddsProfit();
        _step5_ManagerUpdatesExchangeRateAfterProfit();
        _step6_AliceRequestsWithdrawal();
        _step7_TimeTravelPastWithdrawDelay();
        _step7_5_ManagerRedeemsFromRwaMock();
        _step8_AliceCompletesWithdrawal();
    }

    function _step1_AliceDeposits() internal {
        WBTC.mint(alice, INITIAL_DEPOSIT);

        vm.startPrank(alice);
        WBTC.approve(address(boringVault), INITIAL_DEPOSIT);

        uint256 expectedShares = lens.previewDeposit(WBTC, INITIAL_DEPOSIT, boringVault, accountant);       
        uint256 shares = teller.deposit(WBTC, INITIAL_DEPOSIT, 0);
        vm.stopPrank();

        assertEq(shares, expectedShares, "Alice should have received shares");
        assertEq(boringVault.balanceOf(alice), shares, "Alice should have received shares");
        assertEq(WBTC.balanceOf(address(boringVault)), INITIAL_DEPOSIT, "BoringVault should have WBTC");
    }

    function _step2_ManagerInvestsToRwaMock() internal {
        // First, create merkle tree for deposit operation
        setSourceChainName("test");
        setAddress(false, "test", "boringVault", address(boringVault));
        setAddress(false, "test", "rawDataDecoderAndSanitizer", address(decoderAndSanitizer));
        setAddress(false, "test", "managerAddress", address(manager));
        setAddress(false, "test", "accountantAddress", address(accountant));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafIndex = type(uint256).max;

        // Approve RwaMock to spend WBTC
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(WBTC),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve RwaMock to spend WBTC",
            address(decoderAndSanitizer)
        );
        leafs[leafIndex].argumentAddresses[0] = address(rwaMock);

        // Deposit into RwaMock
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(rwaMock),
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit WBTC into RwaMock",
            address(decoderAndSanitizer)
        );
        leafs[leafIndex].argumentAddresses[0] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        // Set merkle root in manager for strategist
        manager.setManageRoot(strategist, manageTree[manageTree.length - 1][0]);

        // Execute deposit
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(WBTC);
        targets[1] = address(rwaMock);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", address(rwaMock), type(uint256).max);
        targetData[1] = abi.encodeWithSignature("deposit(uint256,address)", INITIAL_DEPOSIT, address(boringVault));

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = address(decoderAndSanitizer);
        decodersAndSanitizers[1] = address(decoderAndSanitizer);

        uint256[] memory values = new uint256[](2);

        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(WBTC.balanceOf(address(boringVault)), 0, "BoringVault should have no WBTC");
        assertEq(WBTC.balanceOf(address(rwaMock)), INITIAL_DEPOSIT, "RwaMock should have WBTC");
        rwaMockShares = rwaMock.balanceOf(address(boringVault));
        assertGt(rwaMockShares, 0, "BoringVault should have RwaMock shares");
    }

    function _step3_ManagerUpdatesInitialExchangeRate() internal {
        // Warp time to ensure minimum delay has passed since contract deployment
        vm.warp(block.timestamp + 1 days / 4 + 1);
        // Calculate initial exchange rate based on RwaMock's totalAssets / totalSupply
        uint256 rwaMockTotalAssets = rwaMock.totalAssets();
        uint256 rwaMockTotalSupply = rwaMock.totalSupply();
        initialExchangeRate = uint96(rwaMockTotalAssets * 1e18 / rwaMockTotalSupply);
        vm.prank(strategist);
        accountant.updateExchangeRate(initialExchangeRate);
        
        // Unpause if the contract was paused due to timing or bounds
        (,,,,,,,, bool isPaused,,,) = accountant.accountantState();
        if (isPaused) {
            accountant.unpause();
        }
    }

    function _step4_ManagerAddsProfit() internal {
        vm.prank(strategist);
        rwaMock.addProfit(PROFIT_AMOUNT);

        assertEq(WBTC.balanceOf(address(rwaMock)), INITIAL_DEPOSIT + PROFIT_AMOUNT, "RwaMock should have profit");
    }

    function _step5_ManagerUpdatesExchangeRateAfterProfit() internal {
        // Calculate new exchange rate based on updated totalAssets / totalSupply
        uint256 rwaMockTotalAssets = rwaMock.totalAssets();
        uint256 rwaMockTotalSupply = rwaMock.totalSupply();
        newExchangeRate = uint96(rwaMockTotalAssets * 1e18 / rwaMockTotalSupply);
        vm.warp(block.timestamp + 1 days / 4 + 1); // Ensure minimum delay has passed
        vm.prank(strategist);
        accountant.updateExchangeRate(newExchangeRate);

        console.log("New exchange rate:", newExchangeRate);
    }

    function _step6_AliceRequestsWithdrawal() internal {
        aliceShares = boringVault.balanceOf(alice);
        vm.startPrank(alice);
        boringVault.approve(address(delayedWithdrawer), aliceShares);
        delayedWithdrawer.requestWithdraw(WBTC, uint96(aliceShares), 0, true); // allow third party
        vm.stopPrank();
    }

    function _step7_TimeTravelPastWithdrawDelay() internal {
        vm.warp(block.timestamp + 3 days + 1);
    }

    function _step7_5_ManagerRedeemsFromRwaMock() internal {
        uint256 rwaMockSharesToRedeem = rwaMock.balanceOf(address(boringVault));
        
        // Redeem all RwaMock shares to get WBTC back to the vault
        address[] memory redeemTargets = new address[](1);
        redeemTargets[0] = address(rwaMock);
        bytes[] memory redeemData = new bytes[](1);
        redeemData[0] = abi.encodeWithSignature("redeem(uint256,address,address)", rwaMockSharesToRedeem, address(boringVault), address(boringVault));
        uint256[] memory redeemValues = new uint256[](1);
        
        // Use manager to call manage (manager has MANAGER_ROLE)
        vm.prank(address(manager));
        boringVault.manage(redeemTargets, redeemData, redeemValues);
    }

    function _step8_AliceCompletesWithdrawal() internal {
        uint256 balanceBefore = WBTC.balanceOf(alice);
        vm.prank(alice);
        uint256 assetsOut = delayedWithdrawer.completeWithdraw(WBTC, alice);
        uint256 balanceAfter = WBTC.balanceOf(alice);

        console.log("Assets out:", assetsOut);
        console.log("Alice balance before:", balanceBefore);
        console.log("Alice balance after:", balanceAfter);

        // Alice should receive more than initial deposit due to profit
        assertGt(assetsOut, INITIAL_DEPOSIT, "Alice should receive more than initial deposit");
        assertEq(balanceAfter - balanceBefore, assetsOut, "Alice should receive assets");
        assertEq(boringVault.balanceOf(alice), 0, "Alice should have no shares left");
    }
}

