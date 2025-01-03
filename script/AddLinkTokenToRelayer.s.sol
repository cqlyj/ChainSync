// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AddLinkTokenToRelayer is Script {
    using SafeERC20 for IERC20;

    uint256 constant AMOUNT = 20e18;
    address constant SEPOLIA_LINK_ADDRESS =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;

    function addLinkTokenToRelayer(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        IERC20(SEPOLIA_LINK_ADDRESS).approve(mostRecentlyDeployed, AMOUNT);
        IERC20(SEPOLIA_LINK_ADDRESS).safeTransfer(mostRecentlyDeployed, AMOUNT);
        vm.stopBroadcast();

        console.log("Link token added to Relayer.");
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Relayer",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        addLinkTokenToRelayer(mostRecentlyDeployed);
    }
}
