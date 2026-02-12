// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

library MantraMainnetConstants {
    // ==========================================
    // External Addresses (Mantra Testnet/Mainnet)
    // ==========================================
    address internal constant mUSD = 0x4B545d0758eda6601B051259bD977125fbdA7ba2;
    address internal constant WETH = address(0);

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
    // Maxi Yield Vault Configuration
    // ==========================================
    string internal constant MAXI_NAME = "Maxi Yield Vault V1.0";
    string internal constant MAXI_SYMBOL = "my-mUSD";
    uint8 internal constant MAXI_DECIMALS = 6;
    string internal constant MAXI_TOKEN_NAME = "Maxi Yield mUSD";

    // ==========================================
    // Points Vault Configuration
    // ==========================================
    string internal constant POINTS_NAME = "Points Vault V1.0";
    string internal constant POINTS_SYMBOL = "pts-mUSD";
    uint8 internal constant POINTS_DECIMALS = 6;
    string internal constant POINTS_TOKEN_NAME = "Points mUSD";

    // ==========================================
    // Accountant Configuration
    // ==========================================
    // @notice Starting exchange rate (decimals match base asset, so 1e6 = 1.0)
    uint96 internal constant ACCOUNTANT_STARTING_EXCHANGE_RATE = 1e6;

    // @notice The allowed upper bound multiplier. 1.5e4 = 15000 bps = 1.5x.
    // NewRate must be <= CurrentRate * 1.5
    uint16 internal constant ACCOUNTANT_ALLOWED_EXCHANGE_RATE_CHANGE_UPPER =
        1.5e4;

    // @notice The allowed lower bound multiplier. 0.5e4 = 5000 bps = 0.5x.
    // NewRate must be >= CurrentRate * 0.5
    uint16 internal constant ACCOUNTANT_ALLOWED_EXCHANGE_RATE_CHANGE_LOWER =
        0.5e4;

    // @notice Minimum time between exchange rate updates
    uint64 internal constant ACCOUNTANT_MINIMUM_UPDATE_DELAY = 20 hours;

    // @notice Annual platform fee in basis points (e.g., 0 = 0%)
    uint16 internal constant ACCOUNTANT_PLATFORM_FEE = 0;

    // @notice Performance fee on yield in basis points (e.g., 0 = 0%)
    uint16 internal constant ACCOUNTANT_PERFORMANCE_FEE = 0;

    // ==========================================
    // Teller Configuration
    // ==========================================
    uint64 internal constant TELLER_SHARE_LOCK_PERIOD = 86400; // 24 hours

    // ==========================================
    // Delayed Withdraw Configuration
    // ==========================================
    // @notice Seconds before a requested withdrawal can be completed
    uint32 internal constant DW_WITHDRAW_DELAY = 0;

    // @notice Window in seconds that a withdrawal can be completed after maturity
    uint32 internal constant DW_COMPLETION_WINDOW = 7 days;

    // @notice Fee charged when withdrawal is completed (in basis points)
    uint16 internal constant DW_WITHDRAW_FEE = 0;

    // @notice Maximum loss allowed when evaluating exchange rate diff (in basis points, 100 = 1%)
    uint16 internal constant DW_MAX_LOSS = 100;
}
