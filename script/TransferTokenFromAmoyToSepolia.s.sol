// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {AmoyTokenTransfer} from "src/AmoyTokenTransfer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TransferTokenFromAmoyToSepolia is Script {
    using SafeERC20 for IERC20;

    uint64 constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;
    address constant RECEIVER = 0xFB6a372F2F51a002b390D18693075157A459641F;
    address constant TOKEN = 0xcab0EF91Bee323d1A617c0a027eE753aFd6997E4;
    uint256 constant AMOUNT = 1e15; // 0.0001 ETH

    AmoyTokenTransfer amoyTokenTransfer;

    function sendCCIPBnMTokenToThisContract() public {
        vm.startBroadcast();
        IERC20(TOKEN).approve(address(amoyTokenTransfer), AMOUNT);
        IERC20(TOKEN).safeTransfer(address(amoyTokenTransfer), AMOUNT);
        vm.stopBroadcast();

        console.log(
            "CCIP BnM token sent to contract address.",
            address(amoyTokenTransfer)
        );
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "AmoyTokenTransfer",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        amoyTokenTransfer = AmoyTokenTransfer(payable(mostRecentlyDeployed));

        // send CCIP BnM token to this contract first
        sendCCIPBnMTokenToThisContract();

        // then transfer from Amoy to Sepolia
        vm.startBroadcast();
        amoyTokenTransfer.transferTokensPayLINK(
            SEPOLIA_CHAIN_SELECTOR,
            RECEIVER,
            TOKEN,
            AMOUNT
        );
        vm.stopBroadcast();

        console.log("Transfer from Amoy to Sepolia!");
    }
}
