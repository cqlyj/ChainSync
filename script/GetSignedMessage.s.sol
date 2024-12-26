// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Receiver} from "../src/Receiver.sol";

contract GetSignedMessage is Script {
    Receiver receiver;

    function getSignedMessage(address mostRecentlyDeployed) public {
        receiver = Receiver(payable(mostRecentlyDeployed));
        bytes memory signedMessage = receiver.getSignedMessage();
        console.log("Signed message: ");
        console.logBytes(signedMessage);
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Receiver",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        getSignedMessage(mostRecentlyDeployed);
    }
}
