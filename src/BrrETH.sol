// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract BrrETH is ERC4626 {
    using SafeTransferLib for address;

    string private constant _NAME = "Brrito Liquid-Staked Compound ETH";
    string private constant _SYMBOL = "brrETH";
    address private constant _WETH = 0x4200000000000000000000000000000000000006;
    address private constant _CWETHV3 =
        0x46e6b214b524310239732D51387075E0e70970bf;

    constructor() {
        _WETH.safeApprove(_CWETHV3, type(uint256).max);
    }

    function name() public pure override returns (string memory) {
        return _NAME;
    }

    function symbol() public pure override returns (string memory) {
        return _SYMBOL;
    }

    function asset() public pure override returns (address) {
        return _CWETHV3;
    }
}
