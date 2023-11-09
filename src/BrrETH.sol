// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from "solady/tokens/ERC4626.sol";

contract BrrETH is ERC4626 {
    string private constant _NAME = "Brrito Liquid-Staked Compound ETH";
    string private constant _SYMBOL = "brrETH";
    address private constant _CWETHV3 =
        0x46e6b214b524310239732D51387075E0e70970bf;

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
