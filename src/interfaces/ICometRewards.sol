// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICometRewards {
    struct RewardConfig {
        address token;
        uint64 rescaleFactor;
        bool shouldUpscale;
        // Note: We define new variables after existing variables to keep interface backwards-compatible
        uint256 multiplier;
    }

    function claim(address comet, address src, bool shouldAccrue) external;

    function rewardConfig(address) external view returns (RewardConfig memory);
}
