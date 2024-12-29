// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Sender} from "../src/Sender.sol";

contract DeploySender is Script {
    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        Sender sender;
        (, , , address router, , , address link) = helperConfig
            .activeNetworkConfig();

        vm.startBroadcast();
        sender = new Sender(router, link);
        vm.stopBroadcast();

        console.log("Sender deployed at chainid: ", block.chainid);
        console.log("Sender address: ", address(sender));
    }
}
