// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Receiver} from "../src/Receiver.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployReceiver is Script {
    address constant SEPOLIA_ROUTER =
        0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address constant SEPOLIA_LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    function run() public {
        Receiver receiver;

        vm.startBroadcast();
        receiver = new Receiver(SEPOLIA_ROUTER, SEPOLIA_LINK);
        vm.stopBroadcast();
    }
}
