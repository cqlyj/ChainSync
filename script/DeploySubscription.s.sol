// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Subscription} from "src/Subscription.sol";

contract DeploySubscription is Script {
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;

    function run() public {
        Subscription subscription;

        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            ,
            address ccipRouter,
            bytes memory encodedSubscriptionChainsSelector,
            address allowedTokenForPrimaryChain,
            address allowedTokenForOptionalChain,

        ) = helperConfig.activeNetworkConfig();

        address checkBalanceAddress = DevOpsTools.get_most_recent_deployment(
            "CheckBalance",
            block.chainid
        );

        address sender = DevOpsTools.get_most_recent_deployment(
            "Sender",
            block.chainid
        );

        address receiver = DevOpsTools.get_most_recent_deployment(
            "Receiver",
            SEPOLIA_CHAIN_ID
        );

        uint64[] memory subscriptionChainsSelector = abi.decode(
            encodedSubscriptionChainsSelector,
            (uint64[])
        );

        vm.startBroadcast();
        subscription = new Subscription(
            subscriptionChainsSelector,
            allowedTokenForPrimaryChain,
            allowedTokenForOptionalChain,
            ccipRouter,
            checkBalanceAddress,
            sender,
            receiver
        );

        vm.stopBroadcast();
    }
}
