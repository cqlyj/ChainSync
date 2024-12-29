// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CheckBalance} from "../src/CheckBalance.sol";

contract DeployCheckBalance is Script {
    function run() public {
        CheckBalance checkBalance;
        HelperConfig helperConfig = new HelperConfig();
        (, address functionRouter, bytes32 donID, , , ) = helperConfig
            .activeNetworkConfig();

        vm.startBroadcast();
        checkBalance = new CheckBalance(functionRouter, donID);
        vm.stopBroadcast();

        console.log("CheckBalance deployed at chain ID: ", block.chainid);
        console.log(
            "CheckBalance deployed at address: ",
            address(checkBalance)
        );
    }
}
