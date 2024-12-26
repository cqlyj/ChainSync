// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Sender} from "../src/Sender.sol";

contract SendCCIPMessage is Script {
    Sender sender;
    uint64 constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;

    // For now just say hello
    // This message will be used to sign the message for transfer token
    bytes signedMessage = abi.encodePacked("Hello, Sepolia!");

    function sendCCIPMessage(
        address senderAddress,
        address receiverAddress
    ) public {
        sender = Sender(senderAddress);
        vm.startBroadcast();
        sender.sendMessage(
            SEPOLIA_CHAIN_SELECTOR,
            receiverAddress,
            signedMessage
        );
        vm.stopBroadcast();

        console.log("CCIP message sent from SepoliaSender to AmoyReceiver.");
    }

    function run() public {
        address senderAddress = DevOpsTools.get_most_recent_deployment(
            "Sender",
            block.chainid
        );
        console.log("Most recently deployed Sender address: ", senderAddress);

        address receiverAddress = DevOpsTools.get_most_recent_deployment(
            "Receiver",
            SEPOLIA_CHAIN_ID
        );
        console.log(
            "Most recently deployed Receiver address: ",
            receiverAddress
        );

        sendCCIPMessage(senderAddress, receiverAddress);
    }
}
