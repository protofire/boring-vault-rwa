// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

library MantraConstants {
    // ==========================================
    // USER CONFIGURATION
    // ==========================================

    /* 
    EXAMPLE:
    1. RATE_UPDATER: The address (e.g. Cron Job Bot) that updates exchange rates.
    2. MANAGER: The address (e.g. Multisig) for pausing/emergency actions.
    3. OWNER: The address (e.g. Multisig) that will OWN the system after deployment.
    */

    // --- Testnet (Dukong) ---
    address internal constant RATE_UPDATER_TESTNET =
        0x37723e376FdF70854665B5f1a5C49cB30E1691AC;
    address internal constant MANAGER_TESTNET =
        0x09676Ee4685B618d0DCc85E221019c9Ce3810211;
    address internal constant OWNER_TESTNET =
        0x09676Ee4685B618d0DCc85E221019c9Ce3810211;

    // --- Mainnet ---
    address internal constant RATE_UPDATER_MAINNET =
        0x37723e376FdF70854665B5f1a5C49cB30E1691AC;
    address internal constant MANAGER_MAINNET =
        0x9bbf09dEC8B93CE548eA6fE50e9786964e47Ee5e;
    address internal constant OWNER_MAINNET =
        0x9bbf09dEC8B93CE548eA6fE50e9786964e47Ee5e;

    // ==========================================
    // INTERNAL CONSTANTS
    // ==========================================

    // --- External Tokens ---
    // Testnet (Dukong)
    address internal constant mUSD_TESTNET =
        0x4B545d0758eda6601B051259bD977125fbdA7ba2;
    address internal constant WETH_TESTNET = address(0);

    // Mainnet (Placeholder)
    address internal constant mUSD_MAINNET =
        0xd2b95283011E47257917770D28Bb3EE44c849f6F;
    address internal constant WETH_MAINNET = address(0);

    // ==========================================
    // Roles Authority Configuration
    // ==========================================

    /*
    DEPLOYER_ROLE (id=1)
    Purpose: Permission to deploy contracts via helper Deployer.
    Applied in current deploy scripts:
      - script/01_DeployDeployer.s.sol:
          capability: Deployer.deployContract()
          contract: Deployer
          grantee: deployer EOA (MANTRA_DEPLOYER)
    Role holder: dedicated deployer key or deployment multisig.
    */
    uint8 internal constant DEPLOYER_ROLE = 1;

    /*
    MANAGER_ROLE (id=1)
    Purpose: Generic operational/admin permissions (manage/pause/config/update).
    Applied in current deploy scripts:
      - Not explicitly granted in 01-04 scripts.
      - Same id as DEPLOYER_ROLE, so any capability attached to role id=1
        is effectively shared between MANAGER_ROLE and DEPLOYER_ROLE.
    Typical holder: Multisig or admin EOA.
    */
    uint8 internal constant MANAGER_ROLE = DEPLOYER_ROLE;

    /*
    MINTER_ROLE (id=2)
    Purpose: Mint BoringVault shares through vault.enter().
    Applied in current deploy scripts:
      - script/02_DeployRFRYieldVault.s.sol:
      - script/03_DeployPointsVault.s.sol:  
          capability: BoringVault.enter()
          contract: RFR Yield BoringVault, Points BoringVault
          grantee: RFR Yield TellerWithMultiAssetSupport, Points TellerWithMultiAssetSupport
    Role holder: Teller contract that processes deposits.
    */
    uint8 internal constant MINTER_ROLE = 2;

    /*
    BURNER_ROLE (id=3)
    Purpose: Burn BoringVault shares through vault.exit() during withdrawals/refunds.
    Applied in current deploy scripts:
      - script/02_DeployRFRYieldVault.s.sol:
      - script/03_DeployPointsVault.s.sol:
          capability: BoringVault.exit()
          contract: RFR Yield BoringVault, Points BoringVault
          grantee: RFR Yield DelayedWithdraw, Points DelayedWithdraw
    Role holder: withdrawal coordinator contract (DelayedWithdraw).
    */
    uint8 internal constant BURNER_ROLE = 3;

    /*
    OWNER_ROLE (id=8)
    Purpose: Day-to-day configuration for Teller/Withdraw flows.
    Applied in current deploy scripts:
      - script/02_DeployRFRYieldVault.s.sol:
      - script/03_DeployPointsVault.s.sol:
          TellerWithMultiAssetSupport.setShareLockPeriod()
          TellerWithMultiAssetSupport.updateAssetData()
          DelayedWithdraw.setupWithdrawAsset()
          DelayedWithdraw.setPullFundsFromVault()
          contract: RFR Yield | Points TellerWithMultiAssetSupport, RFR Yield | Points DelayedWithdraw
          grantee: owner EOA (MANTRA_DEPLOYER)
    Role holder: operations multisig (preferable) or trusted admin EOA.
    */
    uint8 internal constant OWNER_ROLE = 8;

    /*
    UPDATE_EXCHANGE_RATE_ROLE (id=11)
    Purpose: Call accountant.updateExchangeRate() to move vault share price.
    Applied in current deploy scripts:
      - script/02_DeployRFRYieldVault.s.sol:
      - script/02_DeployRFRYieldVault.s.sol:      
          contract: RFR Yield AccountantWithRateProviders, Points AccountantWithFixedRate
          grantee: owner EOA (MANTRA_DEPLOYER)
          capability: AccountantWithRateProviders.updateExchangeRate()
    Role holder: dedicated updater bot/service with strict monitoring.
    */
    uint8 internal constant UPDATE_EXCHANGE_RATE_ROLE = 11;

    // ==========================================
    // Contract Names
    // ==========================================

    // Arctic Lens
    string internal constant ARCTIC_LENS_NAME = "Lens V1.0";

    // RFR Yield Vault
    string internal constant RFR_VAULT_NAME = "wmantraUSD (Yield)";
    string internal constant RFR_SYMBOL = "wmantraUSD-Yld";
    uint8 internal constant RFR_DECIMALS = 6;
    string internal constant RFR_TOKEN_NAME = "wmantraUSD (Yield)";
    string internal constant RFR_ACCOUNTANT_NAME =
        "wmantraUSD (Yield) Accountant v1.0";
    string internal constant RFR_TELLER_NAME = "wmantraUSD (Yield) Teller v1.0";
    string internal constant RFR_DW_NAME =
        "wmantraUSD (Yield) DelayedWithdraw v1.0";

    // Points Vault
    string internal constant POINTS_VAULT_NAME = "wmantraUSD (Points)";
    string internal constant POINTS_SYMBOL = "wmantraUSD-Pts";
    uint8 internal constant POINTS_DECIMALS = 6;
    string internal constant POINTS_TOKEN_NAME = "wmantraUSD (Points)";
    string internal constant POINTS_ACCOUNTANT_NAME =
        "wmantraUSD (Points) Accountant v1.0";
    string internal constant POINTS_TELLER_NAME =
        "wmantraUSD (Points) Teller v1.0";
    string internal constant POINTS_DW_NAME =
        "wmantraUSD (Points) DelayedWithdraw v1.0";

    // ==========================================
    // Accountant Configuration
    // ==========================================
    uint96 internal constant ACCOUNTANT_STARTING_EXCHANGE_RATE = 1e6;
    uint16 internal constant ACCOUNTANT_ALLOWED_EXCHANGE_RATE_CHANGE_UPPER =
        1.5e4;
    uint16 internal constant ACCOUNTANT_ALLOWED_EXCHANGE_RATE_CHANGE_LOWER =
        0.5e4;
    uint64 internal constant ACCOUNTANT_MINIMUM_UPDATE_DELAY = 20 hours;
    uint16 internal constant ACCOUNTANT_PLATFORM_FEE = 0;
    uint16 internal constant ACCOUNTANT_PERFORMANCE_FEE = 500;

    // ==========================================
    // Teller Configuration
    // ==========================================
    uint64 internal constant TELLER_SHARE_LOCK_PERIOD = 86400; // 24 hours

    // ==========================================
    // Delayed Withdraw Configuration
    // ==========================================
    uint32 internal constant DW_WITHDRAW_DELAY = 0; // zero delay on withdraw
    uint32 internal constant DW_COMPLETION_WINDOW = 7 days;
    uint16 internal constant DW_WITHDRAW_FEE = 0;
    uint16 internal constant DW_MAX_LOSS = 100; // 1%
}
