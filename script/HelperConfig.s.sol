// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        string chainBaseUrl;
        address tokenAddress;
        address subscriber;
        address router; // function router
        bytes32 donID;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 421614) {
            activeNetworkConfig = getArbitrumConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilChainConfig();
        }
    }

    function getArbitrumConfig() private pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                chainBaseUrl: "sepolia-explorer.arbitrum.io",
                tokenAddress: 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D,
                subscriber: 0xFB6a372F2F51a002b390D18693075157A459641F,
                router: 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C,
                donID: 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000
            });
    }

    function getSepoliaConfig() private pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                chainBaseUrl: "eth-sepolia.blockscout.com",
                tokenAddress: 0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05,
                subscriber: 0xFB6a372F2F51a002b390D18693075157A459641F,
                router: 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0,
                donID: 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000
            });
    }

    // come back when test
    function getOrCreateAnvilChainConfig()
        private
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                chainBaseUrl: "",
                tokenAddress: address(0),
                subscriber: address(0),
                router: address(0),
                donID: 0x0
            });
    }
}
