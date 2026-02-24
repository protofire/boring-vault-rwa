// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console} from "forge-std/Test.sol";
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
import {MantraConstants as Constants} from "script/00_MantraConstants.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol, decimals) {}
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MantraPermissionsVerificationTest is Test {
    RolesAuthority public auth;
    Deployer public deployer;

    BoringVault public maxiVault;
    AccountantWithRateProviders public maxiAccountant;
    TellerWithMultiAssetSupport public maxiTeller;
    DelayedWithdraw public maxiDelayedWithdraw;

    BoringVault public pointsVault;
    AccountantWithFixedRate public pointsAccountant;
    TellerWithMultiAssetSupport public pointsTeller;
    DelayedWithdraw public pointsDelayedWithdraw;

    address public contractOwner = address(0xDE1);
    address public roleHolder = address(0xDE2);
    address public manager = address(0xDE3);
    address public rateUpdater = address(0xDE4);
    address public payoutAddress = address(0xDE5);

    MockERC20 public mUSD;

    function setUp() public {
        // Deploy mock token first
        mUSD = new MockERC20("Mock USD", "mUSD", 6);

        // We mock a deployment state that mirrors what the scripts do
        vm.startPrank(contractOwner);

        auth = new RolesAuthority(contractOwner, Authority(address(0)));
        deployer = new Deployer(contractOwner, auth);

        // Grant owner permission to deploy
        auth.setRoleCapability(
            1,
            address(deployer),
            Deployer.deployContract.selector,
            true
        );
        auth.setUserRole(contractOwner, 1, true);

        // Deploy Maxi
        maxiVault = BoringVault(
            payable(
                deployer.deployContract(
                    "Maxi",
                    type(BoringVault).creationCode,
                    abi.encode(contractOwner, "M", "S", 6),
                    0
                )
            )
        );
        maxiAccountant = AccountantWithRateProviders(
            deployer.deployContract(
                "MaxiAcc",
                type(AccountantWithRateProviders).creationCode,
                abi.encode(
                    contractOwner,
                    address(maxiVault),
                    payoutAddress,
                    1e6,
                    address(mUSD),
                    1.5e4,
                    0.5e4,
                    20 hours,
                    0,
                    0
                ),
                0
            )
        );
        maxiTeller = TellerWithMultiAssetSupport(
            payable(
                deployer.deployContract(
                    "MaxiTel",
                    type(TellerWithMultiAssetSupport).creationCode,
                    abi.encode(
                        contractOwner,
                        address(maxiVault),
                        address(maxiAccountant),
                        address(0)
                    ),
                    0
                )
            )
        );
        maxiDelayedWithdraw = DelayedWithdraw(
            deployer.deployContract(
                "MaxiDW",
                type(DelayedWithdraw).creationCode,
                abi.encode(
                    contractOwner,
                    address(maxiVault),
                    address(maxiAccountant),
                    contractOwner
                ),
                0
            )
        );

        // Deploy Points
        pointsVault = BoringVault(
            payable(
                deployer.deployContract(
                    "Points",
                    type(BoringVault).creationCode,
                    abi.encode(contractOwner, "P", "S", 6),
                    0
                )
            )
        );
        pointsAccountant = AccountantWithFixedRate(
            deployer.deployContract(
                "PointsAcc",
                type(AccountantWithFixedRate).creationCode,
                abi.encode(
                    contractOwner,
                    address(pointsVault),
                    contractOwner,
                    1e6,
                    address(mUSD),
                    1.5e4,
                    0.5e4,
                    20 hours,
                    0,
                    0
                ),
                0
            )
        );
        pointsTeller = TellerWithMultiAssetSupport(
            payable(
                deployer.deployContract(
                    "PointsTel",
                    type(TellerWithMultiAssetSupport).creationCode,
                    abi.encode(
                        contractOwner,
                        address(pointsVault),
                        address(pointsAccountant),
                        address(0)
                    ),
                    0
                )
            )
        );
        pointsDelayedWithdraw = DelayedWithdraw(
            deployer.deployContract(
                "PointsDW",
                type(DelayedWithdraw).creationCode,
                abi.encode(
                    contractOwner,
                    address(pointsVault),
                    address(pointsAccountant),
                    contractOwner
                ),
                0
            )
        );

        // Apply same authority to all
        maxiVault.setAuthority(auth);
        maxiAccountant.setAuthority(auth);
        maxiTeller.setAuthority(auth);
        maxiDelayedWithdraw.setAuthority(auth);

        pointsVault.setAuthority(auth);
        pointsAccountant.setAuthority(auth);
        pointsTeller.setAuthority(auth);
        pointsDelayedWithdraw.setAuthority(auth);

        // Apply Role Setup (Mirrored from scripts)
        _applyRoleSetup();

        vm.stopPrank();
    }

    function _applyRoleSetup() internal {
        // MINTER_ROLE (2)
        auth.setRoleCapability(
            Constants.MINTER_ROLE,
            address(maxiVault),
            BoringVault.enter.selector,
            true
        );
        auth.setUserRole(address(maxiTeller), Constants.MINTER_ROLE, true);

        // BURNER_ROLE (3)
        auth.setRoleCapability(
            Constants.BURNER_ROLE,
            address(maxiVault),
            BoringVault.exit.selector,
            true
        );
        auth.setUserRole(
            address(maxiDelayedWithdraw),
            Constants.BURNER_ROLE,
            true
        );

        // OWNER_ROLE (8) - The new capabilities we added
        // Maxi Accountant
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiAccountant),
            AccountantWithRateProviders.updatePlatformFee.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiAccountant),
            AccountantWithRateProviders.updatePerformanceFee.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiAccountant),
            AccountantWithRateProviders.updatePayoutAddress.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiAccountant),
            AccountantWithRateProviders.unpause.selector,
            true
        );

        // Points Accountant
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(pointsAccountant),
            AccountantWithRateProviders.updatePayoutAddress.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(pointsAccountant),
            AccountantWithFixedRate.setYieldDistributor.selector,
            true
        );

        // DelayedWithdraw
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiDelayedWithdraw),
            DelayedWithdraw.setupWithdrawAsset.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiDelayedWithdraw),
            DelayedWithdraw.changeWithdrawFee.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(pointsDelayedWithdraw),
            DelayedWithdraw.setupWithdrawAsset.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(pointsDelayedWithdraw),
            DelayedWithdraw.changeWithdrawFee.selector,
            true
        );

        // Teller
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiTeller),
            TellerWithMultiAssetSupport.setShareLockPeriod.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiTeller),
            TellerWithMultiAssetSupport.updateAssetData.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiTeller),
            TellerWithMultiAssetSupport.pause.selector,
            true
        );
        auth.setRoleCapability(
            Constants.OWNER_ROLE,
            address(maxiTeller),
            TellerWithMultiAssetSupport.denyAll.selector,
            true
        );

        auth.setUserRole(roleHolder, Constants.OWNER_ROLE, true);

        // MANAGER_ROLE (1)
        auth.setUserRole(manager, Constants.MANAGER_ROLE, true);

        // Grant MANAGER_ROLE manage capability on Vault
        auth.setRoleCapability(
            Constants.MANAGER_ROLE,
            address(maxiVault),
            bytes4(keccak256("manage(address,bytes,uint256)")),
            true
        );
        auth.setRoleCapability(
            Constants.MANAGER_ROLE,
            address(maxiVault),
            bytes4(keccak256("manage(address[],bytes[],uint256[])")),
            true
        );

        // UPDATE_EXCHANGE_RATE_ROLE (11)
        auth.setRoleCapability(
            Constants.UPDATE_EXCHANGE_RATE_ROLE,
            address(maxiAccountant),
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        auth.setUserRole(
            rateUpdater,
            Constants.UPDATE_EXCHANGE_RATE_ROLE,
            true
        );
    }

    // --- Tests ---

    function testOwnerCanChangeFees() public {
        vm.startPrank(roleHolder);

        // 1. Verify Maxi Performance Fee change
        maxiAccountant.updatePerformanceFee(25); // 25 bps
        (, , , , , , , , , , , uint16 performanceFee) = maxiAccountant
            .accountantState();
        assertEq(performanceFee, 25, "Maxi Performance fee should be 25 bps");

        // 2. Verify Points Performance Fee change (SHOULD REVERT now)
        vm.expectRevert();
        pointsAccountant.updatePerformanceFee(25);

        // 3. Verify Withdraw Fee change
        // First setup asset
        maxiDelayedWithdraw.setupWithdrawAsset(
            ERC20(address(mUSD)),
            0,
            7 days,
            0,
            100
        );

        maxiDelayedWithdraw.changeWithdrawFee(ERC20(address(mUSD)), 50); // 50 bps
        (, , , , uint16 withdrawFee, ) = maxiDelayedWithdraw.withdrawAssets(
            ERC20(address(mUSD))
        );
        assertEq(withdrawFee, 50, "Withdraw fee should be 50 bps");

        vm.stopPrank();
    }

    function testManagerPermissions() public {
        vm.startPrank(manager);

        // Manager has Role ID 1, which in this system is also the DEPLOYER_ROLE.
        // We should verify that manager CANNOT change fees (unless explicitly granted).

        vm.expectRevert();
        maxiAccountant.updatePerformanceFee(100);

        vm.stopPrank();
    }

    function testUnprivilegedUserCannotChangeFees() public {
        address hacker = address(0xBAD);
        vm.startPrank(hacker);

        vm.expectRevert();
        maxiAccountant.updatePerformanceFee(100);

        vm.stopPrank();
    }

    function testFeeWithdrawalFlow() public {
        // 1. Setup Performance Fee (25 bps)
        vm.prank(roleHolder);
        maxiAccountant.updatePerformanceFee(25);

        // 2. Accumulate Fees (Simulate logic: rate goes from 1.0 to 1.1)
        // Give Vault some mUSD to pay fees
        mUSD.mint(address(maxiVault), 1000e6);

        // Mint some shares so total supply > 0
        mUSD.mint(address(this), 1000e6);
        mUSD.approve(address(maxiVault), 1000e6);
        vm.prank(address(maxiTeller));
        maxiVault.enter(address(this), mUSD, 1000e6, address(this), 1000e6);

        // Warp to avoid update delay pause
        vm.warp(block.timestamp + 1 days);

        // Checkpoint shares by calling updateExchangeRate once with current rate
        vm.prank(rateUpdater);
        maxiAccountant.updateExchangeRate(1.0e6);

        // Update exchange rate to 1.1e6 after another 1 day
        vm.warp(block.timestamp + 1 days);
        vm.prank(rateUpdater);
        maxiAccountant.updateExchangeRate(1.1e6);

        // If the accountant paused (auto-pause), unpause it (Owner has unpause rights)
        (, , , , , bool isPaused, , , , , , , , ) = maxiAccountant
            .accountantState();
        if (isPaused) {
            vm.prank(roleHolder);
            maxiAccountant.unpause();
        }

        // Check fees owed
        (, , uint128 feesOwedInBase, , , , , , , , , ) = maxiAccountant
            .accountantState();
        assertTrue(feesOwedInBase > 0, "Fees should have accumulated");

        // 3. Manager Withdrawal Flow
        vm.startPrank(manager);

        // A. Approve Accountant to take fees from Vault
        // Data for: mUSD.approve(accountant, type(uint256).max)
        bytes memory approveData = abi.encodeWithSelector(
            ERC20.approve.selector,
            address(maxiAccountant),
            type(uint256).max
        );
        maxiVault.manage(address(mUSD), approveData, 0);

        // B. Claim Fees
        // Data for: accountant.claimFees(mUSD)
        bytes memory claimData = abi.encodeWithSelector(
            AccountantWithRateProviders.claimFees.selector,
            address(mUSD)
        );
        maxiVault.manage(address(maxiAccountant), claimData, 0);

        vm.stopPrank();

        // 4. Verify Payout
        uint256 payoutBalance = mUSD.balanceOf(payoutAddress);
        assertTrue(
            payoutBalance > 0,
            "Payout address should have received fees"
        );
        assertEq(
            payoutBalance,
            uint256(feesOwedInBase),
            "Payout should match fees owed"
        );
    }
}
