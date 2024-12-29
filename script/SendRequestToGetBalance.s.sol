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
    uint64 constant AMOY_SUBSCRIPTION_ID = 394;
    string constant SEPOLIA_CHAIN_BASE_URL = "eth-sepolia.blockscout.com";
    address owner;

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
        checkBalance.setSubscriptionAsOwner(owner);
        checkBalance.sendRequest(false, AMOY_SUBSCRIPTION_ID, args);
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
            address subscriber,
            ,
            ,
            ,
            ,
            ,
            address paymentTokenForOptionalChain,

        ) = helperConfig.activeNetworkConfig();

        /*//////////////////////////////////////////////////////////////
                               ATTENTION
        //////////////////////////////////////////////////////////////*/
        // For now just set the owner to the subscriber, but in fact the owner should be the subscription contract!
        owner = subscriber;

        sendRequestToGetBalance(
            mostRecentlyDeployed,
            SEPOLIA_CHAIN_BASE_URL,
            paymentTokenForOptionalChain,
            subscriber
        );
    }
}
