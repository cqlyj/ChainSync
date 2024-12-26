// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library ReceiverSignedMessage {
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
