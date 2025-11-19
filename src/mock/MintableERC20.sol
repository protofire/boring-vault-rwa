// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

/**
 * @title MintableERC20
 * @notice A mintable ERC20 token for testing purposes
 */
contract MintableERC20 is ERC20 {
    constructor() ERC20("Mock WBTC", "mWBTC", 18) {}

    /**
     * @notice Mint tokens to a specified address
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

