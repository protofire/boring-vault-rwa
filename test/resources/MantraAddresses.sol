// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract MantraAddresses {
    // Liquid Ecosystem
    address public deployerAddress = 0x48499D6cCC57E9190A7523525a58bcE28313AE06;
    address public dev0Address = 0x03eE60B0De0d9b48C5A09E73c3fdF80fEB86AeEF;  // owner
    address public dev1Address = 0x03eE60B0De0d9b48C5A09E73c3fdF80fEB86AeEF;
    address public liquidV1PriceRouter = address(0);
    address public liquidPayoutAddress = 0x03eE60B0De0d9b48C5A09E73c3fdF80fEB86AeEF;  // fee receiver
    address public liquidMultisig = address(0);
    address public balancerVault = address(0);

    // DeFi Ecosystem
    address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;


    // ERC20s
    ERC20 public USDC = ERC20(0xDcc8a320dc2Ce505bB37DAb4b47ECE8E3ad1864F);
    ERC20 public WETH = ERC20(0x139847104029584df72Bf1805e2720D2c5ae4728);
    ERC20 public WBTC = ERC20(0x2A8E20Ba7aB3C3A90527EF0d2d970fd22f7C25AB);
    ERC20 public USDT = ERC20(0xCDb248d19195e23a4cdffCa8a67dD8c7f97000D9);


    // Rate providers
    address public WEETH_RATE_PROVIDER = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address public ETHX_RATE_PROVIDER = 0xAAE054B9b822554dd1D9d1F48f892B4585D3bbf0;
    address public UNIETH_RATE_PROVIDER = 0x2c3b8c5e98A6e89AAAF21Deebf5FF9d08c4A9FF7;

    // Chainlink Datafeeds
    address public WETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public WBTC_USD_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

    // Aave V3 Tokens
    ERC20 public aV3WETH = ERC20(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8);
    ERC20 public aV3USDC = ERC20(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c);

    // Rate Providers
    address public cbethRateProvider = 0x7311E4BB8a72e7B300c5B8BDE4de6CdaA822a5b1;
    address public rethRateProvider = 0x1a8F81c256aee9C640e14bB0453ce247ea0DFE6F;
    address public sDaiRateProvider = 0xc7177B6E18c1Abd725F5b75792e5F7A3bA5DBC2c;



    // EigenLayer
    address public strategyManager = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
    address public delegationManager = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;
    address public mETHStrategy = 0x298aFB19A105D59E74658C4C334Ff360BadE6dd2;

}
