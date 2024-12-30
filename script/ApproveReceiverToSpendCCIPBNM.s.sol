// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ApproveReceiverToSpendCCIPBNM is Script {
    uint256 public constant SUBSCRIPTION_FEE = 1e16;
    address public constant SEPOLIA_CCIPBNM =
        0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05;

    function approveReceiverToSpendCCIPBNM(address receiver) public {
        IERC20 ccipbnm = IERC20(SEPOLIA_CCIPBNM);
        vm.startBroadcast();
        ccipbnm.approve(receiver, SUBSCRIPTION_FEE);
        vm.stopBroadcast();

        console.log(
            "Approved %s to spend %s CCIPBNM",
            receiver,
            SUBSCRIPTION_FEE
        );
    }

    function run() public {
        address receiver = DevOpsTools.get_most_recent_deployment(
            "Receiver",
            block.chainid
        );
        console.log("Most recently deployed Receiver address: ", receiver);

        approveReceiverToSpendCCIPBNM(receiver);
    }
}
