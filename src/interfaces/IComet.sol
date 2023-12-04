// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IComet {
    struct UserBasic {
        int104 principal;
        uint64 baseTrackingIndex;
        uint64 baseTrackingAccrued;
        uint16 assetsIn;
        uint8 _reserved;
    }

    function supply(address asset, uint amount) external;

    function withdrawTo(address to, address asset, uint amount) external;

    function userBasic(
        address account
    ) external view returns (UserBasic memory);

    function accrueAccount(address account) external;

    function withdraw(address asset, uint amount) external;
}
