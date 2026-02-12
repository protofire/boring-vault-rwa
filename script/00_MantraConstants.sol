// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

library MantraConstants {
    // ==========================================
    // External Addresses
    // ==========================================

    // --- Testnet (Dukong) ---
    address internal constant mUSD_TESTNET =
        0x4B545d0758eda6601B051259bD977125fbdA7ba2;
    address internal constant WETH_TESTNET = address(0);  // not used

    // --- Mainnet (Placeholder) ---
    address internal constant mUSD_MAINNET = 0xd2b95283011E47257917770D28Bb3EE44c849f6F;
    address internal constant WETH_MAINNET = address(0);  // not used

    // ==========================================
    // Roles Authority Configuration
    // ==========================================
    uint8 internal constant MANAGER_ROLE = 1;
    uint8 internal constant DEPLOYER_ROLE = 1;
    uint8 internal constant MINTER_ROLE = 2;
    uint8 internal constant BURNER_ROLE = 3;
    uint8 internal constant OWNER_ROLE = 8;
    uint8 internal constant MULTISIG_ROLE = 9;
    uint8 internal constant UPDATE_EXCHANGE_RATE_ROLE = 11;

    // ==========================================
    // Contract Names
    // ==========================================

    // Arctic Lens
    string internal constant ARCTIC_LENS_NAME = "Lens V1.0";

    // Maxi Yield Vault
    string internal constant MAXI_VAULT_NAME = "Maxi Yield Vault V1.0";
    string internal constant MAXI_SYMBOL = "MY-mantraUSD";
    uint8 internal constant MAXI_DECIMALS = 6;
    string internal constant MAXI_TOKEN_NAME = "Maxi Yield mantraUSD";
    string internal constant MAXI_ACCOUNTANT_NAME =
        "Maxi Yield Accountant V1.0";
    string internal constant MAXI_TELLER_NAME = "Maxi Yield Teller V1.0";
    string internal constant MAXI_DW_NAME = "Maxi Yield DelayedWithdraw V1.0";

    // Points Vault
    string internal constant POINTS_VAULT_NAME = "Points Vault V1.0";
    string internal constant POINTS_SYMBOL = "PTS-mantraUSD";
    uint8 internal constant POINTS_DECIMALS = 6;
    string internal constant POINTS_TOKEN_NAME = "Points mantraUSD";
    string internal constant POINTS_ACCOUNTANT_NAME = "Points Accountant V1.0";
    string internal constant POINTS_TELLER_NAME = "Points Teller V1.0";
    string internal constant POINTS_DW_NAME = "Points DelayedWithdraw V1.0";

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
    uint16 internal constant ACCOUNTANT_PERFORMANCE_FEE = 0;

    // ==========================================
    // Teller Configuration
    // ==========================================
    uint64 internal constant TELLER_SHARE_LOCK_PERIOD = 86400; // 24 hours

    // ==========================================
    // Delayed Withdraw Configuration
    // ==========================================
    uint32 internal constant DW_WITHDRAW_DELAY = 0;  // zero delay on withdraw
    uint32 internal constant DW_COMPLETION_WINDOW = 7 days;
    uint16 internal constant DW_WITHDRAW_FEE = 0;
    uint16 internal constant DW_MAX_LOSS = 100; // 1%
}
