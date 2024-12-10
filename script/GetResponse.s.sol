// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {CheckBalance} from "../src/CheckBalance.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract GetResponse is Script {
    CheckBalance public checkBalance;

    function getResponse(address checkBalanceAddress) public {
        checkBalance = CheckBalance(checkBalanceAddress);
        vm.startBroadcast();
        uint256 response = checkBalance.getResponse();
        vm.stopBroadcast();
        console.log("Response: ", response);
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "CheckBalance",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        getResponse(mostRecentlyDeployed);
    }
}
