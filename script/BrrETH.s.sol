// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {BrrETH} from "src/BrrETH.sol";

contract BrrETHScript is Script {
    address private constant _BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;
    uint256 private constant _INITIAL_DEPOSIT_AMOUNT = 0.001 ether;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        BrrETH brrETH = new BrrETH(vm.envAddress("OWNER"));

        brrETH.deposit{value: _INITIAL_DEPOSIT_AMOUNT}(_BURN_ADDRESS, 1);

        vm.stopBroadcast();
    }
}
