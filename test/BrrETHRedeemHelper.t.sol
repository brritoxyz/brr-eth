// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BrrETH} from "src/BrrETH.sol";
import {BrrETHRedeemHelper} from "src/BrrETHRedeemHelper.sol";
import {Helper} from "test/Helper.sol";

contract BrrETHRedeemHelperTest is Test, Helper {
    using SafeTransferLib for address;

    address public constant COMET = 0x46e6b214b524310239732D51387075E0e70970bf;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    BrrETHRedeemHelper public immutable redeemHelper;

    receive() external payable {}

    constructor() {
        redeemHelper = new BrrETHRedeemHelper(address(vault));

        vault.approve(address(redeemHelper), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                             redeem
    //////////////////////////////////////////////////////////////*/

    function testRedeem() external {
        uint256 shares = vault.deposit{value: 1 ether}(address(this), 1);

        // The amount of cWETH that will be redeemed from brrETH.
        uint256 assets = vault.convertToAssets(shares);

        uint256 ethBalanceBefore = address(this).balance;

        redeemHelper.redeem(shares, address(this));

        // Account for Comet rounding down and compare against the ETH amount received.
        assertEq(assets - 1, address(this).balance - ethBalanceBefore);

        // The redeem helper should not maintain balances for any of the tokens it handles.
        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, WETH.balanceOf(address(redeemHelper)));
        assertEq(0, address(redeemHelper).balance);
    }

    function testRedeemFuzz(uint8 ethMultiplier) external {
        uint256 msgValue = 1 ether * (uint256(ethMultiplier) + 1);
        uint256 shares = vault.deposit{value: msgValue}(address(this), 1);
        uint256 assets = vault.convertToAssets(shares);

        uint256 ethBalanceBefore = address(this).balance;

        redeemHelper.redeem(shares, address(this));

        // Account for Comet rounding down and compare against the ETH amount received.
        assertLe(assets - 2, address(this).balance - ethBalanceBefore);

        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, WETH.balanceOf(address(redeemHelper)));
        assertEq(0, address(redeemHelper).balance);
    }
}
