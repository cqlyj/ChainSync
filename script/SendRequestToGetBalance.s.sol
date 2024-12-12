// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CheckBalance} from "../src/CheckBalance.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract SendRequestToGetBalance is Script {
    using Strings for uint256;

    HelperConfig public helperConfig;
    CheckBalance public checkBalance;
    uint64 constant SEPOLIA_SUBSCRIPTION_ID = 3995;

    function sendRequestToGetBalance(
        address checkBalanceAddress,
        string memory chainBaseUrl,
        address tokenAddress,
        address subscriber
    ) public {
        checkBalance = CheckBalance(checkBalanceAddress);
        string[] memory args = new string[](3);
        args[0] = chainBaseUrl;
        args[1] = uint256(uint160(tokenAddress)).toHexString();
        args[2] = uint256(uint160(subscriber)).toHexString();

        vm.startBroadcast();
        checkBalance.sendRequest(SEPOLIA_SUBSCRIPTION_ID, args);
        vm.stopBroadcast();
        console.log("Request sent to get balance.");
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "CheckBalance",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        helperConfig = new HelperConfig();
        (
            string memory chainBaseUrl,
            address tokenAddress,
            address subscriber,
            ,
            ,

        ) = helperConfig.activeNetworkConfig();

        sendRequestToGetBalance(
            mostRecentlyDeployed,
            chainBaseUrl,
            tokenAddress,
            subscriber
        );
    }
}
