// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {BrrETHRedeemHelper} from "src/BrrETHRedeemHelper.sol";

contract BrrETHRedeemHelperScript is Script {
    address private constant _BRR_ETH =
        0xf1288441F094d0D73bcA4E57dDd07829B34de681;

    function run() public {
        vm.broadcast(vm.envUint("PRIVATE_KEY"));

        new BrrETHRedeemHelper(_BRR_ETH);
    }
}
