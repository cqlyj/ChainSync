// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Relayer} from "src/Relayer.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployRelayer is Script {
    address constant SEPOLIA_ROUTER =
        0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address constant SEPOLIA_LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    uint256 constant AMOY_CHAINID = 80002;

    function run() public {
        Relayer relayer;
        address subscriptionAddress;

        subscriptionAddress = DevOpsTools.get_most_recent_deployment(
            "Subscription",
            AMOY_CHAINID
        );

        vm.startBroadcast();
        relayer = new Relayer(
            SEPOLIA_ROUTER,
            SEPOLIA_LINK,
            subscriptionAddress
        );
        vm.stopBroadcast();

        console.log("Relayer deployed at chainid: ", block.chainid);
        console.log("Relayer address: ", address(relayer));
    }
}
