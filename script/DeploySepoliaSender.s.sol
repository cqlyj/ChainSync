// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {SepoliaSender} from "../src/SepoliaSender.sol";

contract DeploySepoliaSender is Script {
    address constant SEPOLIA_LINK_ADDRESS =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        SepoliaSender sepoliaSender;
        (, , , , , address ccipRouter) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();

        sepoliaSender = new SepoliaSender(ccipRouter, SEPOLIA_LINK_ADDRESS);

        vm.stopBroadcast();
    }
}
