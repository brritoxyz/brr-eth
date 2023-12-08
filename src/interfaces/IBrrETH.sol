// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBrrETH {
    function redeem(
        uint256 shares,
        address to,
        address owner
    ) external returns (uint256 assets);
}
