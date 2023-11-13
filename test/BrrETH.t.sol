// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {BrrETH} from "src/BrrETH.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

contract BrrETHTest is Test {
    string private constant _NAME = "Rebasing Compound ETH";
    string private constant _SYMBOL = "brrETH";
    address private constant _WETH_ADDR =
        0x4200000000000000000000000000000000000006;
    address private constant _COMET_ADDR =
        0x46e6b214b524310239732D51387075E0e70970bf;
    IWETH private constant _WETH = IWETH(_WETH_ADDR);
    IComet private constant _COMET = IComet(_COMET_ADDR);
    ICometRewards private constant _COMET_REWARDS =
        ICometRewards(0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1);

    BrrETH public immutable vault = new BrrETH();

    /*//////////////////////////////////////////////////////////////
                             constructor
    //////////////////////////////////////////////////////////////*/

    function testConstructor() external {
        assertEq(
            type(uint256).max,
            ERC20(_WETH_ADDR).allowance(address(vault), _COMET_ADDR)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             name
    //////////////////////////////////////////////////////////////*/

    function testName() external {
        assertEq(_NAME, vault.name());
    }

    /*//////////////////////////////////////////////////////////////
                             symbol
    //////////////////////////////////////////////////////////////*/

    function testSymbol() external {
        assertEq(_SYMBOL, vault.symbol());
    }

    /*//////////////////////////////////////////////////////////////
                             asset
    //////////////////////////////////////////////////////////////*/

    function testAsset() external {
        assertEq(_COMET_ADDR, vault.asset());
    }
}
