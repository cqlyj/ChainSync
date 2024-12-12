// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";

/// @title AmoyReceiverAndTokenSender
/// @author Luo Yingjie
/// @notice This contract will receive the message sent from sepolia chain
/// @notice This contract will be deployed on the amoy chain
contract AmoyReceiver is CCIPReceiver {
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        bytes signedMessage // The signed message that approves the token transfer
    );

    bytes32 private s_messageId;
    bytes private s_signedMessage;

    /// @notice Constructor initializes the contract with the router address.
    /// @param router The address of the router contract.
    constructor(address router) CCIPReceiver(router) {}

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        s_messageId = any2EvmMessage.messageId;
        s_signedMessage = any2EvmMessage.data;

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            abi.decode(any2EvmMessage.sender, (address)), // abi-decoding of the sender address,
            abi.decode(any2EvmMessage.data, (bytes)) // abi-decoding of the signed message
        );
    }

    function getMessageId() external view returns (bytes32) {
        return s_messageId;
    }

    function getSignedMessage() external view returns (bytes memory) {
        return s_signedMessage;
    }
}
