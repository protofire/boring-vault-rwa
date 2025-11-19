// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}

contract RwaMock is ERC4626 {
    constructor(
        ERC20 underlyingAsset
    ) ERC4626(underlyingAsset, "RwaMock", "RWA") {}


    function addProfit(uint256 amount) external {
        IERC20Mintable(address(asset)).mint(address(this), amount);
    }
    function addLoss(uint256 amount) external {
        asset.transfer(address(1), amount);
    }


    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}

