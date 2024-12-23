// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {AmoyReceiver} from "../src/AmoyReceiver.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployAmoyReceiver is Script {
    address constant AMOY_ROUTER = 0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2;
    address constant AMOY_LINK = 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904;

    function run() public {
        AmoyReceiver amoyReceiver;

        vm.startBroadcast();
        amoyReceiver = new AmoyReceiver(AMOY_ROUTER, AMOY_LINK);
        vm.stopBroadcast();
    }
}
