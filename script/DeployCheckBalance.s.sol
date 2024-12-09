// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CheckBalance} from "../src/CheckBalance.sol";

contract DeployCheckBalance is Script {
    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        CheckBalance checkBalance;
        (
            string memory chainBaseUrl,
            address tokenAddress,
            address subscriber,
            address router,
            bytes32 donID
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        checkBalance = new CheckBalance(
            chainBaseUrl,
            tokenAddress,
            subscriber,
            router,
            donID
        );
        vm.stopBroadcast();
    }
}
