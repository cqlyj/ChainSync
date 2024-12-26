// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AddLinkTokenToSender is Script {
    using SafeERC20 for IERC20;

    uint256 constant AMOUNT = 3e18; // 3 LINK
    address constant AMOY_LINK_ADDRESS =
        0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904;

    function addLinkTokenToSender(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        IERC20(AMOY_LINK_ADDRESS).approve(mostRecentlyDeployed, AMOUNT);
        IERC20(AMOY_LINK_ADDRESS).safeTransfer(mostRecentlyDeployed, AMOUNT);
        vm.stopBroadcast();

        console.log("Link token added to Sender.");
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Sender",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        addLinkTokenToSender(mostRecentlyDeployed);
    }
}
