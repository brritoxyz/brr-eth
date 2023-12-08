// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {BrrETHRedeemHelper} from "src/BrrETHRedeemHelper.sol";

contract BrrETHRedeemHelperScript is Script {
    function run() public {
        vm.broadcast(vm.envUint("PRIVATE_KEY"));

        new BrrETHRedeemHelper();
    }
}
