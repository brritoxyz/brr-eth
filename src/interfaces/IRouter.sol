// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    function swap(
        address inputToken,
        address outputToken,
        uint256 input,
        uint256 minOutput,
        uint256 routeIndex,
        address referrer
    ) external returns (uint256);

    function getSwapOutput(
        bytes32 pair,
        uint256 input
    ) external view returns (uint256 index, uint256 output);
}
