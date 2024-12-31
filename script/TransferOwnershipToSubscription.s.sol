// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Sender} from "src/Sender.sol";
import {CheckBalance} from "src/CheckBalance.sol";

contract TransferOwnershipToSubscription is Script {
    Sender sender;
    CheckBalance checkBalance;

    function transferOwnershipToSubscription(
        address subscriptionAddress
    ) public {
        vm.startBroadcast();
        sender.setSubscriptionAsOwner(subscriptionAddress);
        checkBalance.setSubscriptionAsOwner(subscriptionAddress);
        vm.stopBroadcast();

        console.log("Ownership transferred to subscription...");
    }

    function run() public {
        address senderAddress = DevOpsTools.get_most_recent_deployment(
            "Sender",
            block.chainid
        );
        console.log("Most recently deployed Sender address: ", senderAddress);

        address checkBalanceAddress = DevOpsTools.get_most_recent_deployment(
            "CheckBalance",
            block.chainid
        );
        console.log(
            "Most recently deployed CheckBalance address: ",
            checkBalanceAddress
        );

        address subscriptionAddress = DevOpsTools.get_most_recent_deployment(
            "Subscription",
            block.chainid
        );

        sender = Sender(payable(senderAddress));
        checkBalance = CheckBalance(payable(checkBalanceAddress));

        transferOwnershipToSubscription(subscriptionAddress);
    }
}
