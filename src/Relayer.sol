// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ILogAutomation, Log} from "./interfaces/ILogAutomation.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/// @title Relayer
/// @author Luo Yingjie
/// @notice This contract will be a relayer which will listen for the event emitted by the Receiver contract => MessageReceived
/// @notice And then will send another message to the Subscription contract
/// @dev That is, this contract will be deployed on the Sepolia chain, and send a message to the Subscription contract on the Amoy chain
/// @dev This message will contain the user address who successfully paid the subscription fee on the Sepolia chain
contract Relayer is ILogAutomation {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;
    uint64 private constant AMOY_CHAIN_SELECTOR = 16281711391670634445;
    address private immutable i_subscriptionAddress;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Relayer__NotEnoughBalance(
        uint256 currentBalance,
        uint256 calculatedFees
    );

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
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    /// @param _link The address of the link contract.
    constructor(address _router, address _link, address _subscription) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
        i_subscriptionAddress = _subscription;
    }

    /*//////////////////////////////////////////////////////////////
                    CHAINLINK LOG TRIGGER AUTOMATION
    //////////////////////////////////////////////////////////////*/

    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        uint64 optionalChain = uint64(uint256(log.topics[1]));
        address paymentTokenForOptionalChain = bytes32ToAddress(log.topics[2]);
        address user = bytes32ToAddress(log.topics[3]);
        performData = abi.encode(
            optionalChain,
            paymentTokenForOptionalChain,
            user
        );
    }

    function performUpkeep(bytes calldata performData) external override {
        // send the message to the Subscription contract
        sendMessage(i_subscriptionAddress, performData);
    }

    /*//////////////////////////////////////////////////////////////
                             CCIP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function sendMessage(
        address receiver,
        bytes calldata message
    ) internal returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: abi.encode(message),
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
        uint256 fees = s_router.getFee(AMOY_CHAIN_SELECTOR, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this)))
            revert Relayer__NotEnoughBalance(
                s_linkToken.balanceOf(address(this)),
                fees
            );

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(s_router), fees);

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(AMOY_CHAIN_SELECTOR, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            AMOY_CHAIN_SELECTOR,
            receiver,
            message,
            address(s_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function bytes32ToAddress(bytes32 _address) public pure returns (address) {
        return address(uint160(uint256(_address)));
    }
}
