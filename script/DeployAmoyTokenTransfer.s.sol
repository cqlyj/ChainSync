// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {AmoyTokenTransfer} from "../src/AmoyTokenTransfer.sol";

contract DeployAmoyTokenTransfer is Script {
    address constant AMOY_ROUTER = 0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2;
    address constant AMOY_LINK_ADDRESS =
        0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904;

    function run() public {
        AmoyTokenTransfer amoyTokenTransfer;

        vm.startBroadcast();
        amoyTokenTransfer = new AmoyTokenTransfer(
            AMOY_ROUTER,
            AMOY_LINK_ADDRESS
        );
        vm.stopBroadcast();
    }
}
