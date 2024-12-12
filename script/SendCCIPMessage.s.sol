// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {SepoliaSender} from "../src/SepoliaSender.sol";

contract SendCCIPMessage is Script {
    SepoliaSender sepoliaSender;
    uint64 constant AMOY_CHAIN_SELECTOR = 16281711391670634445;
    uint256 constant AMOY_CHAIN_ID = 80002;

    // For now just say hello
    // This message will be used to sign the message for transfer token
    bytes signedMessage = abi.encodePacked("Hello, Amoy!");

    function sendCCIPMessage(
        address sepoliaSenderAddress,
        address amoyReceiverAddress
    ) public {
        sepoliaSender = SepoliaSender(sepoliaSenderAddress);
        vm.startBroadcast();
        sepoliaSender.sendMessage(
            AMOY_CHAIN_SELECTOR,
            amoyReceiverAddress,
            signedMessage
        );
        vm.stopBroadcast();

        console.log("CCIP message sent from SepoliaSender to AmoyReceiver.");
    }

    function run() public {
        address sepoliaSenderAddress = DevOpsTools.get_most_recent_deployment(
            "SepoliaSender",
            block.chainid
        );
        console.log(
            "Most recently deployed SepoliaSender address: ",
            sepoliaSenderAddress
        );

        address amoyReceiverAddress = DevOpsTools.get_most_recent_deployment(
            "AmoyReceiver",
            AMOY_CHAIN_ID
        );
        console.log(
            "Most recently deployed AmoyReceiver address: ",
            amoyReceiverAddress
        );

        sendCCIPMessage(sepoliaSenderAddress, amoyReceiverAddress);
    }
}
