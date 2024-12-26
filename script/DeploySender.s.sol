// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Sender} from "../src/Sender.sol";

contract DeploySender is Script {
    address constant AMOY_LINK_ADDRESS =
        0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904;

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        Sender sender;
        (, , , , , address ccipRouter) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();

        sender = new Sender(ccipRouter, AMOY_LINK_ADDRESS);

        vm.stopBroadcast();
    }
}
