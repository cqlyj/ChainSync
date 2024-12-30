// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title ReceiverSignedMessage
/// @author Luo Yingjie
/// @notice This library defines the signed message structure for the receiver

library ReceiverSignedMessage {
    /// @notice The signed message structure for the receiver
    /// @param chainSelector The target chain selector
    /// @param user The signer's address
    /// @param token The token on the destination chain to transfer
    /// @param amount The amount to transfer
    /// @param transferContract The contract address for transfer, first transfer to this contract, then router will transfer to the target chain => Receiver
    /// @param router The router address for approval => destination chain's router
    /// @param nonce The nonce for replay protection
    /// @param expiry The expiry timestamp

    struct SignedMessage {
        uint64 chainSelector; // Include the target chain selector
        address user; // Signer's address
        address token; // Token to transfer
        uint256 amount; // Amount to transfer
        address transferContract; // Contract address for transfer, first transfer to this contract, then router will transfer to the target chain
        address router; // Router address for approval
        uint256 nonce; // Nonce for replay protection
        uint256 expiry; // Expiry timestamp
    }
}
