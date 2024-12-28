// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract MockCheckBalance {
    function sendRequest(
        bool /*isNativeToken*/,
        uint64 /*subscriptionId*/,
        string[] calldata /*args*/
    ) external pure returns (bytes32 requestId) {
        // do nothing
        return bytes32(0);
    }

    function setSubscriptionAsOwner(address subscription) external {
        // do nothing
    }
}
