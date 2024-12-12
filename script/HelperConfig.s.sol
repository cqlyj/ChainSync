// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";

// We will deploy the contract on Amoy chain and the optional chain is Sepolia
contract HelperConfig is Script {
    struct NetworkConfig {
        string chainBaseUrl;
        address tokenAddress;
        address subscriber;
        address router; // function router
        bytes32 donID;
        address ccipRouter; // ccip router
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilChainConfig();
        }
    }

    function getSepoliaConfig() private pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                chainBaseUrl: "eth-sepolia.blockscout.com",
                tokenAddress: 0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05,
                subscriber: 0xFB6a372F2F51a002b390D18693075157A459641F,
                router: 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0,
                donID: 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000,
                ccipRouter: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59
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
                donID: 0x0,
                ccipRouter: address(0)
            });
    }
}
