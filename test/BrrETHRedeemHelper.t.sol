// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BrrETH} from "src/BrrETH.sol";
import {BrrETHRedeemHelper} from "src/BrrETHRedeemHelper.sol";

contract BrrETHRedeemHelperTest is Test {
    using SafeTransferLib for address;

    BrrETH public constant BRR_ETH =
        BrrETH(0xf1288441F094d0D73bcA4E57dDd07829B34de681);
    address public constant COMET = 0x46e6b214b524310239732D51387075E0e70970bf;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    BrrETHRedeemHelper public immutable redeemHelper = new BrrETHRedeemHelper();

    receive() external payable {}

    constructor() {
        BRR_ETH.approve(address(redeemHelper), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                             redeem
    //////////////////////////////////////////////////////////////*/

    function testRedeem() external {
        uint256 shares = BRR_ETH.deposit{value: 1 ether}(address(this));

        // The amount of cWETH that will be redeemed from brrETH.
        uint256 assets = BRR_ETH.convertToAssets(shares);

        uint256 ethBalanceBefore = address(this).balance;

        redeemHelper.redeem(shares, address(this));

        // Account for Comet rounding down and compare against the ETH amount received.
        assertEq(assets - 1, address(this).balance - ethBalanceBefore);

        // The redeem helper should not maintain balances for any of the tokens it handles.
        assertEq(0, BRR_ETH.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, WETH.balanceOf(address(redeemHelper)));
        assertEq(0, address(redeemHelper).balance);
    }

    function testRedeemFuzz(uint8 ethMultiplier) external {
        uint256 msgValue = 1 ether * (uint256(ethMultiplier) + 1);
        uint256 shares = BRR_ETH.deposit{value: msgValue}(address(this));
        uint256 assets = BRR_ETH.convertToAssets(shares);

        uint256 ethBalanceBefore = address(this).balance;

        redeemHelper.redeem(shares, address(this));

        // Account for Comet rounding down and compare against the ETH amount received.
        assertLe(assets - 2, address(this).balance - ethBalanceBefore);

        assertEq(0, BRR_ETH.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, WETH.balanceOf(address(redeemHelper)));
        assertEq(0, address(redeemHelper).balance);
    }
}
