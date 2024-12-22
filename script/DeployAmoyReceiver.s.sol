// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {AmoyReceiver} from "../src/AmoyReceiver.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployAmoyReceiver is Script {
    address constant AMOY_ROUTER = 0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2;

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "AmoyTokenTransfer",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);
        AmoyReceiver amoyReceiver;

        vm.startBroadcast();
        amoyReceiver = new AmoyReceiver(AMOY_ROUTER, mostRecentlyDeployed);
        vm.stopBroadcast();
    }
}
