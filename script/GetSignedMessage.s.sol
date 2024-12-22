// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {AmoyReceiver} from "../src/AmoyReceiver.sol";

contract GetSignedMessage is Script {
    AmoyReceiver amoyReceiver;

    function getSignedMessage(address mostRecentlyDeployed) public {
        amoyReceiver = AmoyReceiver(payable(mostRecentlyDeployed));
        bytes memory signedMessage = amoyReceiver.getSignedMessage();
        console.log("Signed message: ");
        console.logBytes(signedMessage);
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "AmoyReceiver",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        getSignedMessage(mostRecentlyDeployed);
    }
}
