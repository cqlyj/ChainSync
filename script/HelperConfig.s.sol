// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";

// We will deploy the contract on Amoy chain and the optional chain is Sepolia
contract HelperConfig is Script {
    struct NetworkConfig {
        address subscriber;
        address functionRouter;
        bytes32 donID;
        address ccipRouter;
        // decode this to uint64[] to get the subscription chains
        bytes subscriptionChainsSelector;
        address allowedTokenForPrimaryChain;
        address allowedTokenForOptionalChain;
        address link;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 80002) {
            activeNetworkConfig = getAmoyConfig();
        }
    }

    function getAmoyConfig() private pure returns (NetworkConfig memory) {
        uint64[] memory subscriptionChainsSelector = new uint64[](1);
        subscriptionChainsSelector[0] = 16281711391670634445;
        bytes memory encodedSubscriptionChainsSelector = abi.encode(
            subscriptionChainsSelector
        );
        return
            NetworkConfig({
                subscriber: 0xFB6a372F2F51a002b390D18693075157A459641F,
                functionRouter: 0xC22a79eBA640940ABB6dF0f7982cc119578E11De,
                donID: 0x66756e2d706f6c79676f6e2d616d6f792d310000000000000000000000000000,
                ccipRouter: 0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2,
                subscriptionChainsSelector: encodedSubscriptionChainsSelector,
                allowedTokenForPrimaryChain: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904,
                allowedTokenForOptionalChain: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904,
                link: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904
            });
    }
}
