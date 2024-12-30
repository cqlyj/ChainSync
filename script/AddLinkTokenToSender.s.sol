// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract AddLinkTokenToSender is Script {
    using SafeERC20 for IERC20;

    uint256 constant AMOUNT = 5e18; // 5 LINK
    HelperConfig helperConfig;

    function addLinkTokenToSender(address mostRecentlyDeployed) public {
        helperConfig = new HelperConfig();
        (, , , , , , , address link) = helperConfig.activeNetworkConfig();
        vm.startBroadcast();
        IERC20(link).approve(mostRecentlyDeployed, AMOUNT);
        IERC20(link).safeTransfer(mostRecentlyDeployed, AMOUNT);
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
