// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {BrrETH} from "src/BrrETH.sol";
import {BrrETHRedeemHelper} from "src/BrrETHRedeemHelper.sol";

contract BrrETHRedeemHelperTest is Test {
    BrrETH public constant BRR_ETH =
        BrrETH(0xf1288441F094d0D73bcA4E57dDd07829B34de681);
    BrrETHRedeemHelper public immutable redeemer = new BrrETHRedeemHelper();

    receive() external payable {}

    constructor() {
        BRR_ETH.approve(address(redeemer), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                             redeem
    //////////////////////////////////////////////////////////////*/

    function testRedeem() external {
        uint256 shares = BRR_ETH.deposit{value: 1 ether}(address(this));

        // The amount of cWETH that will be redeemed from brrETH.
        uint256 assets = BRR_ETH.convertToAssets(shares);

        uint256 ethBalanceBefore = address(this).balance;

        redeemer.redeem(shares, address(this));

        // Account for Comet rounding down and compare against the ETH amount received.
        assertEq(assets - 1, address(this).balance - ethBalanceBefore);
    }

    function testRedeemFuzz(uint8 ethMultiplier) external {
        uint256 msgValue = 1 ether * (uint256(ethMultiplier) + 1);
        uint256 shares = BRR_ETH.deposit{value: msgValue}(address(this));
        uint256 assets = BRR_ETH.convertToAssets(shares);

        uint256 ethBalanceBefore = address(this).balance;

        redeemer.redeem(shares, address(this));

        // Account for Comet rounding down and compare against the ETH amount received.
        assertEq(assets - 1, address(this).balance - ethBalanceBefore);
    }
}
