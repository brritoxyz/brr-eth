// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {BrrETH} from "src/BrrETH.sol";

contract Helper is Test {
    address public immutable owner = address(this);
    BrrETH public immutable vault = new BrrETH(address(this));
    string internal constant _NAME = "Brrito ETH";
    string internal constant _SYMBOL = "brrETH";
    address internal constant _WETH =
        0x4200000000000000000000000000000000000006;
    address internal constant _ROUTER =
        0xafaE5a94e6F1C79D40F5460c47589BAD5c123B9c;
    address internal constant _COMP =
        0x9e1028F5F1D5eDE59748FFceE5532509976840E0;
    address internal constant _COMET =
        0x46e6b214b524310239732D51387075E0e70970bf;
    ICometRewards internal constant _COMET_REWARDS =
        ICometRewards(0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1);
    uint256 internal constant _FEE_BASE = 10_000;
    uint256 internal constant _SWAP_FEE_DEDUCTED = 9_998;
    uint256 internal constant _COMET_ROUNDING_ERROR_MARGIN = 2;
}
