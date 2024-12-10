// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {CheckBalance} from "../src/CheckBalance.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract AddConsumer is Script {
    CheckBalance public checkBalance;
    HelperConfig public helperConfig;
    uint64 constant SEPOLIA_SUBSCRIPTION_ID = 3995;
    address router;

    function addConsumer(
        uint64 subscriptionId,
        address mostRecentlyDeployed
    ) public {
        vm.startBroadcast();
        (bool success, bytes memory data) = router.call(
            abi.encodeWithSignature(
                "addConsumer(uint64,address)",
                subscriptionId,
                mostRecentlyDeployed
            )
        );
        vm.stopBroadcast();

        if (!success) {
            console.log("Failed to add consumer.");
            console.logBytes(data);
        } else {
            console.log("Consumer added.");
        }
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "CheckBalance",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);
        checkBalance = CheckBalance(mostRecentlyDeployed);

        helperConfig = new HelperConfig();
        (, , , address _router, ) = helperConfig.activeNetworkConfig();
        router = _router;
        addConsumer(SEPOLIA_SUBSCRIPTION_ID, mostRecentlyDeployed);
    }
}
