// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract RwaMockDecoderAndSanitizer is BaseDecoderAndSanitizer, ERC4626DecoderAndSanitizer {
    //============================== RWA MOCK ===============================

    function addProfit(uint256 /*amount*/ ) external pure returns (bytes memory addressesFound) {
        // No address parameters to sanitize
        return addressesFound;
    }

    function addLoss(uint256 /*amount*/ ) external pure returns (bytes memory addressesFound) {
        // No address parameters to sanitize
        return addressesFound;
    }

    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}
}

