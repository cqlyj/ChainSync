// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AmoyReceiverSignedMessage} from "./library/AmoyReceiverSignedMessage.sol";

/// @title AmoyReceiver
/// @author Luo Yingjie
/// @notice This contract will receive the message sent from sepolia chain
/// @notice This contract will be deployed on the amoy chain
contract AmoyReceiver is CCIPReceiver, EIP712 {
    error AmoyReceiver__InvalidSignature();

    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        bytes signedMessage // The signed message that approves the token transfer
    );

    bytes32 private s_messageId;
    bytes private s_encodedSignedMessage;
    bytes private s_signedMessage;

    bytes32 private constant MESSAGE_TYPEHASH =
        keccak256(
            "SignedMessage(uint64 chainSelector,address user,address token,uint256 amount,address transferContract,address router,uint256 nonce,uint256 expiry)"
        );

    /// @notice Constructor initializes the contract with the router address.
    /// @param router The address of the router contract.
    constructor(
        address router
    ) CCIPReceiver(router) EIP712("AmoyReceiver", "1") {}

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        s_messageId = any2EvmMessage.messageId;
        s_encodedSignedMessage = any2EvmMessage.data;

        s_signedMessage = abi.decode(s_encodedSignedMessage, (bytes));

        (
            address signer,
            AmoyReceiverSignedMessage.SignedMessage memory signedMessage,
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = abi.decode(
                s_signedMessage,
                (
                    address,
                    AmoyReceiverSignedMessage.SignedMessage,
                    uint8,
                    bytes32,
                    bytes32
                )
            );

        if (!_isValidSignature(signer, signedMessage, v, r, s)) {
            revert AmoyReceiver__InvalidSignature();
        }

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            abi.decode(any2EvmMessage.sender, (address)), // abi-decoding of the sender address,
            abi.decode(any2EvmMessage.data, (bytes)) // abi-decoding of the signed message
        );
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _isValidSignature(
        address signer,
        AmoyReceiverSignedMessage.SignedMessage memory signedMessage,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private view returns (bool) {
        bytes32 digest = getMessageHash(signedMessage);
        (address recoveredSigner, , ) = ECDSA.tryRecover(digest, v, r, s);

        return recoveredSigner == signer;
    }

    function getMessageHash(
        AmoyReceiverSignedMessage.SignedMessage memory signedMessage
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        MESSAGE_TYPEHASH,
                        AmoyReceiverSignedMessage.SignedMessage({
                            chainSelector: signedMessage.chainSelector,
                            user: signedMessage.user,
                            token: signedMessage.token,
                            amount: signedMessage.amount,
                            transferContract: signedMessage.transferContract,
                            router: signedMessage.router,
                            nonce: signedMessage.nonce,
                            expiry: signedMessage.expiry
                        })
                    )
                )
            );
    }

    function getMessageId() external view returns (bytes32) {
        return s_messageId;
    }

    function getEncodedSignedMessage() external view returns (bytes memory) {
        return s_encodedSignedMessage;
    }

    function getSignedMessage() external view returns (bytes memory) {
        return s_signedMessage;
    }
}
