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
import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

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

contract MantraVaultsIntegrationTest is Test {
    // --- State Variables ---
    MockERC20 public mUSD;
    Deployer public deployer;
    RolesAuthority public auth;
    ArcticArchitectureLens public lens;

    // Yield Vault components
    BoringVault public yieldVault;
    AccountantWithRateProviders public yieldAccountant;
    TellerWithMultiAssetSupport public yieldTeller;
    DelayedWithdraw public yieldDelayedWithdraw;

    // Points Vault components
    BoringVault public pointsVault;
    AccountantWithFixedRate public pointsAccountant;
    TellerWithMultiAssetSupport public pointsTeller;
    DelayedWithdraw public pointsDelayedWithdraw;

    address public owner = address(0xDE1);
    address public userA = address(0xA11ce);

    // Standard Project Roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;

    // --- Setup ---
    function setUp() public {
        vm.startPrank(owner);

        // 1. Setup Mock Token
        mUSD = new MockERC20("Mock USD", "mUSD", 6);
        deal(address(mUSD), userA, 1000e6);

        // 2. Deploy Infrastructure
        deployer = new Deployer(owner, Authority(address(0)));
        auth = new RolesAuthority(owner, Authority(address(0)));
        deployer.setAuthority(auth);

        // Grant owner Deployer role (Role 1)
        auth.setRoleCapability(
            1,
            address(deployer),
            Deployer.deployContract.selector,
            true
        );
        auth.setUserRole(owner, 1, true);

        // 3. Deploy Yield Vault via Deployer
        yieldVault = BoringVault(
            payable(
                deployer.deployContract(
                    "Maxi Yield Vault V1.0",
                    type(BoringVault).creationCode,
                    abi.encode(owner, "Maxi Yield mUSD", "my-mUSD", 6),
                    0
                )
            )
        );

        yieldAccountant = AccountantWithRateProviders(
            deployer.deployContract(
                "Maxi Yield Accountant V1.0",
                type(AccountantWithRateProviders).creationCode,
                abi.encode(
                    owner,
                    address(yieldVault),
                    owner,
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

        yieldTeller = TellerWithMultiAssetSupport(
            payable(
                deployer.deployContract(
                    "Maxi Yield Teller V1.0",
                    type(TellerWithMultiAssetSupport).creationCode,
                    abi.encode(
                        owner,
                        address(yieldVault),
                        address(yieldAccountant),
                        address(0)
                    ),
                    0
                )
            )
        );

        yieldDelayedWithdraw = DelayedWithdraw(
            deployer.deployContract(
                "Maxi Yield DelayedWithdraw V1.0",
                type(DelayedWithdraw).creationCode,
                abi.encode(
                    owner,
                    address(yieldVault),
                    address(yieldAccountant),
                    owner
                ),
                0
            )
        );

        // 4. Deploy Points Vault via Deployer
        pointsVault = BoringVault(
            payable(
                deployer.deployContract(
                    "Points Vault V1.0",
                    type(BoringVault).creationCode,
                    abi.encode(owner, "Points mUSD", "pts-mUSD", 6),
                    0
                )
            )
        );

        pointsAccountant = AccountantWithFixedRate(
            deployer.deployContract(
                "Points Accountant V1.0",
                type(AccountantWithFixedRate).creationCode,
                abi.encode(
                    owner,
                    address(pointsVault),
                    owner,
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
                    "Points Teller V1.0",
                    type(TellerWithMultiAssetSupport).creationCode,
                    abi.encode(
                        owner,
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
                "Points DelayedWithdraw V1.0",
                type(DelayedWithdraw).creationCode,
                abi.encode(
                    owner,
                    address(pointsVault),
                    address(pointsAccountant),
                    owner
                ),
                0
            )
        );

        // 5. Deploy Lens
        lens = ArcticArchitectureLens(
            deployer.deployContract(
                "Arctic Architecture Lens V1.0",
                type(ArcticArchitectureLens).creationCode,
                hex"",
                0
            )
        );

        // 6. Permissions & Config
        _setupVault(
            yieldVault,
            yieldAccountant,
            yieldTeller,
            yieldDelayedWithdraw
        );
        _setupVault(
            pointsVault,
            pointsAccountant,
            pointsTeller,
            pointsDelayedWithdraw
        );

        vm.stopPrank();
    }

    function _setupVault(
        BoringVault v,
        AccountantWithRateProviders a,
        TellerWithMultiAssetSupport t,
        DelayedWithdraw d
    ) internal {
        v.setAuthority(auth);
        a.setAuthority(auth);
        t.setAuthority(auth);
        d.setAuthority(auth);

        // Minter Role (2)
        auth.setRoleCapability(
            MINTER_ROLE,
            address(v),
            BoringVault.enter.selector,
            true
        );
        auth.setUserRole(address(t), MINTER_ROLE, true);

        // Burner Role (3)
        auth.setRoleCapability(
            BURNER_ROLE,
            address(v),
            BoringVault.exit.selector,
            true
        );
        auth.setUserRole(address(d), BURNER_ROLE, true);

        // Update Rate Role (11)
        auth.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE,
            address(a),
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        auth.setUserRole(owner, UPDATE_EXCHANGE_RATE_ROLE, true);

        // Owner Role (8)
        auth.setRoleCapability(
            OWNER_ROLE,
            address(t),
            TellerWithMultiAssetSupport.setShareLockPeriod.selector,
            true
        );
        auth.setUserRole(owner, OWNER_ROLE, true);

        // Public capabilities for UI interaction
        auth.setPublicCapability(
            address(t),
            TellerWithMultiAssetSupport.deposit.selector,
            true
        );
        auth.setPublicCapability(
            address(d),
            DelayedWithdraw.requestWithdraw.selector,
            true
        );
        auth.setPublicCapability(
            address(d),
            DelayedWithdraw.completeWithdraw.selector,
            true
        );

        t.setShareLockPeriod(24 hours);
        t.updateAssetData(mUSD, true, true, 0);
        d.setupWithdrawAsset(mUSD, 0, 7 days, 0, 100);
        d.setPullFundsFromVault(true);
        v.setBeforeTransferHook(address(t));
    }

    // --- Tests ---

    function testDeterministicDeployment() public {
        assertEq(
            address(yieldVault),
            deployer.getAddress("Maxi Yield Vault V1.0")
        );
        assertEq(
            address(pointsVault),
            deployer.getAddress("Points Vault V1.0")
        );
        assertEq(
            address(lens),
            deployer.getAddress("Arctic Architecture Lens V1.0")
        );
    }

    function testYieldVaultMechanism() public {
        uint256 amount = 100e6;
        vm.startPrank(userA);
        mUSD.approve(address(yieldVault), amount);
        yieldTeller.deposit(mUSD, amount, 0);
        vm.stopPrank();

        assertEq(lens.exchangeRate(yieldAccountant), 1e6);

        deal(
            address(mUSD),
            address(yieldVault),
            mUSD.balanceOf(address(yieldVault)) + 10e6
        );
        vm.prank(owner);
        yieldAccountant.updateExchangeRate(1_100_000);

        assertEq(lens.exchangeRate(yieldAccountant), 1_100_000);
        assertEq(
            lens.balanceOfInAssets(userA, yieldVault, yieldAccountant),
            110e6
        );
    }

    function testPointsVaultMechanism() public {
        uint256 amount = 100e6;
        vm.startPrank(userA);
        mUSD.approve(address(pointsVault), amount);
        pointsTeller.deposit(mUSD, amount, 0);
        vm.stopPrank();

        assertEq(lens.exchangeRate(pointsAccountant), 1e6);

        deal(
            address(mUSD),
            address(pointsVault),
            mUSD.balanceOf(address(pointsVault)) + 10e6
        );
        vm.prank(owner);
        pointsAccountant.updateExchangeRate(1_200_000);

        assertEq(lens.exchangeRate(pointsAccountant), 1_000_000); // Fixed at 1.0
    }

    function testShareLockEnforcement() public {
        vm.startPrank(userA);
        mUSD.approve(address(yieldVault), 10e6);
        yieldTeller.deposit(mUSD, 10e6, 0);

        vm.expectRevert();
        yieldVault.transfer(address(0x1), 1e6);

        skip(24 hours + 1);
        yieldVault.transfer(address(0x1), 1e6);
        vm.stopPrank();
    }
}
