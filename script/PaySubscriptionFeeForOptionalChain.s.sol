// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Subscription} from "src/Subscription.sol";

contract PaySubscriptionFeeForOptionalChain is Script {
    Subscription public subscription;

    address public constant SEPOLIA_CCIPBNM =
        0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05;
    uint64 public constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;
    // @notice update to your signed message
    bytes public constant SIGNED_MESSAGE =
        bytes(
            "0x000000000000000000000000fb6a372f2f51a002b390d18693075157a459641f000000000000000000000000000000000000000000000000de41ba4fc9d91ad9000000000000000000000000fb6a372f2f51a002b390d18693075157a459641f000000000000000000000000fd57b4ddbf88a4e07ff4e34c487b99af2fe82a05000000000000000000000000000000000000000000000000002386f26fc1000000000000000000000000000043368186b983ea41e23ad5b313580ee985f9ba120000000000000000000000000bf3de8c5d3e8a2b34d2beeb17abfcebaf363a590000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006774b388000000000000000000000000000000000000000000000000000000000000001c000ecf780966f957e049eac66874dc1a30e685e3a453e1623ac71ad678683d4c54b3e66f085cb264bb84db5c906653dace966c5a76990a5548393b87333dd35b"
        );

    function payforOptionalChain() public {
        vm.startBroadcast();

        subscription.paySubscriptionFeeForOptionalChain(
            SEPOLIA_CCIPBNM,
            SEPOLIA_CHAIN_SELECTOR,
            SIGNED_MESSAGE
        );

        vm.stopBroadcast();

        console.log("Pay subscription fee for optional chain request sent...");
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Subscription",
            block.chainid
        );
        console.log(
            "Most recently deployed subscription address: ",
            mostRecentlyDeployed
        );

        subscription = Subscription(payable(mostRecentlyDeployed));

        payforOptionalChain();
    }
}
