// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IBrrETH} from "src/interfaces/IBrrETH.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

contract BrrETHRedeemHelper {
    using SafeTransferLib for address;

    IBrrETH public constant BRR_ETH =
        IBrrETH(0xf1288441F094d0D73bcA4E57dDd07829B34de681);
    IComet public constant COMET =
        IComet(0x46e6b214b524310239732D51387075E0e70970bf);
    IWETH public constant WETH =
        IWETH(0x4200000000000000000000000000000000000006);

    receive() external payable {}

    function redeem(uint256 shares, address to) external {
        // Requires approval from the caller to spend their brrETH balance.
        BRR_ETH.redeem(shares, address(this), msg.sender);

        // Comet's alias for an "entire balance" is `type(uint256).max`.
        COMET.withdraw(address(WETH), type(uint256).max);

        WETH.withdraw(WETH.balanceOf(address(this)));
        to.safeTransferETH(address(this).balance);
    }
}
