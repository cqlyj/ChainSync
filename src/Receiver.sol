// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReceiverSignedMessage} from "./library/ReceiverSignedMessage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";

/// @title Receiver
/// @author Luo Yingjie
/// @notice This contract will receive the message sent from Amoy Chain
/// @notice This contract will be deployed on the Sepolia Chain(optional chain)
contract Receiver is CCIPReceiver, EIP712, OwnerIsCreator {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 private s_messageId;
    bytes private s_encodedSignedMessage;
    bytes private s_signedMessage;

    bytes32 private constant MESSAGE_TYPEHASH =
        keccak256(
            "SignedMessage(uint64 chainSelector,address user,address token,uint256 amount,address transferContract,address router,uint256 nonce,uint256 expiry)"
        );
    IRouterClient private s_router;
    IERC20 private s_linkToken;
    // The current chain selector
    uint64 private constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;
    // The destination chain selector
    uint64 private constant AMOY_CHAIN_SELECTOR = 16281711391670634445;
    // The owner address where the token was transferred
    // This is also the owner of the Subscription contract
    address private immutable i_ownerAddress =
        0xFB6a372F2F51a002b390D18693075157A459641F;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Receiver__InvalidSignature();
    error Receiver__InvalidReceiverAddress(); // Used when the receiver address is 0.
    error Receiver__NotEnoughBalance(
        uint256 currentBalance,
        uint256 calculatedFees
    ); // Used to make sure contract has enough balance to cover the fees.
    error AmoyReceiver__NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error AmoyReceiver__FailedToWithdrawEth(
        address owner,
        address target,
        uint256 value
    ); // Used when the withdrawal of Ether fails.

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MessageReceived(
        bytes32 messageId, // The unique ID of the message.
        uint64 sourceChainSelector, // The chain selector of the source chain.
        uint64 indexed currentChainSelector, // The chain selector of the current chain.
        address sender, // The address of the sender from the source chain.
        bytes signedMessage, // The signed message that approves the token transfer
        address indexed tokenTransferred, // The token that was transferred
        address indexed signer // The signer of the message
    );
    // Event emitted when the tokens are transferred to an account on another chain.
    event TokensTransferred(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        address token, // The token address that was transferred.
        uint256 tokenAmount, // The token amount that was transferred.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the message.
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Modifier that checks the receiver address is not 0.
    /// @param _receiver The receiver address.
    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert Receiver__InvalidReceiverAddress();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    /// @param _link The address of the LINK token.
    constructor(
        address _router,
        address _link
    ) CCIPReceiver(_router) EIP712("Receiver", "1") {
        s_router = IRouterClient(_router);
        s_linkToken = IERC20(_link);
    }

    /*//////////////////////////////////////////////////////////////
                     RECEIVE AND FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is transferred to the contract without any data.
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
    /// @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
    /// @param _beneficiary The address to which the tokens will be sent.
    /// @param _token The contract address of the ERC20 token to be withdrawn.
    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(_token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert AmoyReceiver__NothingToWithdraw();

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferTokensPayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount
    ) internal validateReceiver(_receiver) returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        //  address(linkToken) means fees are paid in LINK
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _token,
            _amount,
            address(s_linkToken)
        );

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(
            _destinationChainSelector,
            evm2AnyMessage
        );

        if (fees > s_linkToken.balanceOf(address(this)))
            revert Receiver__NotEnoughBalance(
                s_linkToken.balanceOf(address(this)),
                fees
            );

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(s_router), fees);

        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        IERC20(_token).approve(address(s_router), _amount);

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(
            _destinationChainSelector,
            evm2AnyMessage
        );

        // Emit an event with message details
        emit TokensTransferred(
            messageId,
            _destinationChainSelector,
            _receiver,
            _token,
            _amount,
            address(s_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for tokens transfer.
    /// @param _receiver The address of the receiver.
    /// @param _token The token to be transferred.
    /// @param _amount The amount of the token to be transferred.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Set the token amounts
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), // ABI-encoded receiver address
                data: "", // No data
                tokenAmounts: tokenAmounts, // The amount and type of token being transferred
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit and allowing out-of-order execution.
                    // Best Practice: For simplicity, the values are hardcoded. It is advisable to use a more dynamic approach
                    // where you set the extra arguments off-chain. This allows adaptation depending on the lanes, messages,
                    // and ensures compatibility with future CCIP upgrades. Read more about it here: https://docs.chain.link/ccip/best-practices#using-extraargs
                    Client.EVMExtraArgsV2({
                        gasLimit: 0, // Gas limit for the callback on the destination chain
                        allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
                    })
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: _feeTokenAddress
            });
    }

    function _execute(
        ReceiverSignedMessage.SignedMessage memory signedMessage
    ) internal {
        IERC20(signedMessage.token).safeTransferFrom(
            signedMessage.user,
            signedMessage.transferContract,
            signedMessage.amount
        );

        // The destination chain will be where the tokens are transferred
        transferTokensPayLINK(
            AMOY_CHAIN_SELECTOR,
            i_ownerAddress,
            signedMessage.token,
            signedMessage.amount
        );
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        s_messageId = any2EvmMessage.messageId;
        s_encodedSignedMessage = any2EvmMessage.data;

        s_signedMessage = abi.decode(s_encodedSignedMessage, (bytes));

        (
            address signer,
            ReceiverSignedMessage.SignedMessage memory signedMessage,
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = abi.decode(
                s_signedMessage,
                (
                    address,
                    ReceiverSignedMessage.SignedMessage,
                    uint8,
                    bytes32,
                    bytes32
                )
            );

        if (!_isValidSignature(signer, signedMessage, v, r, s)) {
            revert Receiver__InvalidSignature();
        }

        _execute(signedMessage);

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            SEPOLIA_CHAIN_SELECTOR, // the current chain selector
            abi.decode(any2EvmMessage.sender, (address)), // abi-decoding of the sender address,
            abi.decode(any2EvmMessage.data, (bytes)), // abi-decoding of the signed message
            signedMessage.token, // the token transferred
            signer // the signer of the message
        );
    }

    function _isValidSignature(
        address signer,
        ReceiverSignedMessage.SignedMessage memory signedMessage,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (bool) {
        // @audit Here we should do more checks
        bytes32 digest = getMessageHash(signedMessage);
        (address recoveredSigner, , ) = ECDSA.tryRecover(digest, v, r, s);
        uint256 expiry = signedMessage.expiry;
        if (recoveredSigner != signer || block.timestamp >= expiry) {
            return false;
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getMessageHash(
        ReceiverSignedMessage.SignedMessage memory signedMessage
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        MESSAGE_TYPEHASH,
                        ReceiverSignedMessage.SignedMessage({
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

    function getLinkToken() external view returns (IERC20) {
        return s_linkToken;
    }
}
