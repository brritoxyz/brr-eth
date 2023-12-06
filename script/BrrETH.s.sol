// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {BrrETH} from "src/BrrETH.sol";

contract BrrETHScript is Script {
    function run() public {
        vm.broadcast(vm.envUint("PRIVATE_KEY"));

        new BrrETH(vm.envAddress("OWNER"));
    }
}
