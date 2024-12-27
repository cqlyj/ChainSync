// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Sender
/// @author Luo Yingjie
/// @notice This contract will send a cross chain message from Amoy to Sepolia to trigger the token transfer
/// @dev This contract will be deployed on the Amoy chain
contract Sender is Ownable {
    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;

    bool private s_initialized;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    // Custom errors to provide more descriptive revert messages.
    error Sender__NotEnoughBalance(
        uint256 currentBalance,
        uint256 calculatedFees
    ); // Used to make sure contract has enough balance.
    error Sender__AlreadyInitialized();
    error Sender__NotInitialized();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        bytes signedMessage, // The signed message that approves the token transfer
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier initializedOnlyOnce() {
        if (s_initialized) {
            revert Sender__AlreadyInitialized();
        }
        _;
    }

    modifier hasInitialized() {
        if (!s_initialized) {
            revert Sender__NotInitialized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    /// @param _link The address of the link contract.
    constructor(address _router, address _link) Ownable(msg.sender) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
        s_initialized = false;
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setSubscriptionAsOwner(
        address subscription
    ) external onlyOwner initializedOnlyOnce {
        transferOwnership(subscription);
        s_initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // This function should send the data which includes the amount to send, token address, and receiver address, and sign the approval of the token transfer
    function sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        bytes calldata signedMessage // This is the signed message that approves the token transfer
    ) external onlyOwner hasInitialized returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: abi.encode(signedMessage),
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and allowing out-of-order execution.
                // Best Practice: For simplicity, the values are hardcoded. It is advisable to use a more dynamic approach
                // where you set the extra arguments off-chain. This allows adaptation depending on the lanes, messages,
                // and ensures compatibility with future CCIP upgrades. Read more about it here: https://docs.chain.link/ccip/best-practices#using-extraargs
                Client.EVMExtraArgsV2({
                    gasLimit: 800_000, // Gas limit for the callback on the destination chain
                    allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
                })
            ),
            // Set the feeToken address, indicating LINK will be used for fees
            feeToken: address(s_linkToken)
        });

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(
            destinationChainSelector,
            evm2AnyMessage
        );

        if (fees > s_linkToken.balanceOf(address(this)))
            revert Sender__NotEnoughBalance(
                s_linkToken.balanceOf(address(this)),
                fees
            );

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(s_router), fees);

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            destinationChainSelector,
            receiver,
            signedMessage,
            address(s_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }
}
