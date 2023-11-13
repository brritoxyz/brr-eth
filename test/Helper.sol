// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solady/tokens/ERC20.sol";
import {BrrETH} from "src/BrrETH.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

contract Helper {
    string internal constant _NAME = "Rebasing Compound ETH";
    string internal constant _SYMBOL = "brrETH";
    address internal constant _WETH_ADDR =
        0x4200000000000000000000000000000000000006;
    address internal constant _COMET_ADDR =
        0x46e6b214b524310239732D51387075E0e70970bf;
    IWETH internal constant _WETH = IWETH(_WETH_ADDR);
    IComet internal constant _COMET = IComet(_COMET_ADDR);
    ICometRewards internal constant _COMET_REWARDS =
        ICometRewards(0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1);
}
