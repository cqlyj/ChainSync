// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {CheckBalance} from "../src/CheckBalance.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract GetBalance is Script {
    CheckBalance public checkBalance;

    function getBalance(address checkBalanceAddress) public {
        checkBalance = CheckBalance(checkBalanceAddress);
        vm.startBroadcast();
        uint256 balance = checkBalance.getBalance();
        vm.stopBroadcast();
        console.log("Balance: ", balance);
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "CheckBalance",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        getBalance(mostRecentlyDeployed);
    }
}
