// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Subscription} from "src/Subscription.sol";

contract PaySubscriptionFeeForOptionalChain is Script {
    Subscription public subscription;

    address public constant SEPOLIA_CCIPBNM =
        0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05;
    uint64 public constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;

    /// @notice update to your signed message
    bytes public constant SIGNED_MESSAGE = bytes("");

    function payforOptionalChain() public {
        vm.startBroadcast();

        subscription.paySubscriptionFeeForOptionalChain(
            SEPOLIA_CCIPBNM,
            SEPOLIA_CHAIN_SELECTOR,
            SIGNED_MESSAGE
        );

        vm.stopBroadcast();

        console.log("Pay subscription fee for optional chain request sent...");
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Subscription",
            block.chainid
        );
        console.log(
            "Most recently deployed subscription address: ",
            mostRecentlyDeployed
        );

        subscription = Subscription(payable(mostRecentlyDeployed));

        payforOptionalChain();
    }
}
