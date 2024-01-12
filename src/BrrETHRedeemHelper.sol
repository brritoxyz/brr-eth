// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IBrrETH} from "src/interfaces/IBrrETH.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

contract BrrETHRedeemHelper {
    using SafeTransferLib for address;

    IComet private constant _COMET =
        IComet(0x46e6b214b524310239732D51387075E0e70970bf);
    IWETH private constant _WETH =
        IWETH(0x4200000000000000000000000000000000000006);
    IBrrETH public immutable brrETH;

    receive() external payable {}

    constructor(address _brrETH) {
        brrETH = IBrrETH(_brrETH);
    }

    /**
     * @notice Redeem brrETH for ETH.
     * @param  shares  uint256  Amount of shares to redeem.
     * @param  to      address  ETH recipient.
     */
    function redeem(uint256 shares, address to) external {
        // Requires approval from the caller to spend their brrETH balance.
        brrETH.redeem(shares, address(this), msg.sender);

        // Comet's alias for an "entire balance" is `type(uint256).max`.
        _COMET.withdraw(address(_WETH), type(uint256).max);

        _WETH.withdraw(_WETH.balanceOf(address(this)));
        to.safeTransferETH(address(this).balance);
    }
}
