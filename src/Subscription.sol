// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CheckBalance} from "./CheckBalance.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ILogAutomation, Log} from "./interfaces/ILogAutomation.sol";
import {Sender} from "./Sender.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Subscription is ILogAutomation, CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;
    using Strings for uint256;
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private constant SUBSCRIPTION_FEE = 1e16; // 0.01 ether
    uint64 private constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;
    uint64 private constant SEPOLIA_SUBSCRIPTION_ID = 3995;
    address private immutable i_receiver;
    address private s_sepoliaCheckBalanceAddress;
    uint64[] private s_subscriptionChainsSelector;
    address private s_allowedToken;
    address private s_allowedTokenForOptionalChain;
    IRouterClient private s_router;
    mapping(address subscriber => Subscriptions subscription)
        private s_subscriberToSubscription;
    Sender private s_sender;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Subscription__InvalidChain();
    error Subscription__NotEnoughMoney(uint256 currentBalance);
    error Subscription__TransferFailed();
    error Subscription__InvalidToken();
    error Subscription__AddConsumerFailed();
    error Subscription__WithdrawFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscriberToSubscriptionUpdated(
        address indexed subscriber,
        address paymentTokenForPrimaryChain,
        address paymentTokenForOptionalChain,
        uint64 optionalChain
    );

    event Withdrawn(address token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Subscriptions {
        address paymentTokenForPrimaryChain;
        address paymentTokenForOptionalChain;
        uint64 optionalChain;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint64[] memory _subscriptionChainsSelector,
        address _allowedToken,
        address _allowedTokenForOptionalChain,
        address _router,
        address _sepoliaCheckBalanceAddress,
        address _sender,
        address _receiver
    ) CCIPReceiver(_router) Ownable(msg.sender) {
        s_subscriptionChainsSelector = _subscriptionChainsSelector;
        s_allowedToken = _allowedToken;
        s_allowedTokenForOptionalChain = _allowedTokenForOptionalChain;
        s_router = IRouterClient(_router);
        s_sepoliaCheckBalanceAddress = _sepoliaCheckBalanceAddress;
        s_sender = Sender(_sender);
        i_receiver = _receiver;
    }

    /*//////////////////////////////////////////////////////////////
                     RECEIVE AND FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    fallback() external payable {}

    /*//////////////////////////////////////////////////////////////
                    CHAINLINK LOG TRIGGER AUTOMATION
    //////////////////////////////////////////////////////////////*/

    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        uint256 balance = uint256(log.topics[2]);
        performData = abi.encode(balance);
    }

    function performUpkeep(bytes calldata performData) external pure override {
        uint256 balance = abi.decode(performData, (uint256));
        if (balance < SUBSCRIPTION_FEE) {
            revert Subscription__NotEnoughMoney(balance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             CCIP RECEIVER
    //////////////////////////////////////////////////////////////*/

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        // get the message data
        bytes memory encodedData = abi.decode(any2EvmMessage.data, (bytes));

        (
            uint64 optionalChain,
            address paymentTokenForOptionalChain,
            address user
        ) = abi.decode(encodedData, (uint64, address, address));

        // update the subscription
        s_subscriberToSubscription[user] = Subscriptions(
            s_subscriberToSubscription[user].paymentTokenForPrimaryChain,
            paymentTokenForOptionalChain,
            optionalChain
        );

        // emit the event
        emit SubscriberToSubscriptionUpdated(
            user,
            s_subscriberToSubscription[user].paymentTokenForPrimaryChain,
            paymentTokenForOptionalChain,
            optionalChain
        );
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function paySubscriptionFeeforOptionalChain(
        address paymentTokenForOptionalChain,
        uint64 optionalChain,
        bytes memory signedMessage // signed message to approve and transfer the token
    ) public {
        // This function will call the Chainlink functions to get the balance of the token on the optional chain
        if (
            paymentTokenForOptionalChain != s_allowedTokenForOptionalChain &&
            paymentTokenForOptionalChain != address(0)
        ) {
            revert Subscription__InvalidToken();
        }

        if (!_isValidChain(optionalChain)) {
            revert Subscription__InvalidChain();
        }

        _requestToCheckBalanceOnOptionalChain(
            paymentTokenForOptionalChain,
            optionalChain
        );

        // after request it will take some time to get the response
        // we just directly send the message here to approve and transfer the token
        // if not enough balance, we will still get the error message but we will not be able to revert the transaction because we don't know the balance yet
        // @audit this is not reasonable in production but a good instance to demonstrate the integration of Chainlink techniques

        // @audit we didn't implement the logic to transfer native token here!
        if (paymentTokenForOptionalChain == address(0)) {
            // if the token is native token, just send to the contract on that chain which will emit an event each time it receives the native token
            // it's quite simple, we don't need to sign the message and just deploy the contract on the optional chain and send the native token to it
            // so here we just simply return, those operations can be handled simply in front-end
            return;
        }

        _sendCCIPMessage(optionalChain, signedMessage);
        // after send, receive and transfer the token, the event will be emitted on the optional chain
        // That is, we cannot or listen to the event here to know the result
        // I think here we just need someone to monitor the event on the optional chain
        // That is, we have another sender and this contract will be the receiver again!
    }

    function paySubscriptionFeeForPrimaryChain(
        address paymentTokenForPrimaryChain
    ) public payable {
        if (paymentTokenForPrimaryChain == address(0)) {
            if (msg.value < SUBSCRIPTION_FEE) {
                revert Subscription__NotEnoughMoney(msg.value);
            }

            (bool success, ) = address(this).call{value: SUBSCRIPTION_FEE}("");

            if (!success) {
                revert Subscription__TransferFailed();
            }

            s_subscriberToSubscription[msg.sender] = Subscriptions(
                paymentTokenForPrimaryChain,
                address(0),
                0
            );

            emit SubscriberToSubscriptionUpdated(
                msg.sender,
                paymentTokenForPrimaryChain,
                address(0),
                0
            );
        } else {
            if (paymentTokenForPrimaryChain != s_allowedToken) {
                revert Subscription__InvalidToken();
            }

            IERC20 token = IERC20(paymentTokenForPrimaryChain);

            if (token.balanceOf(msg.sender) < SUBSCRIPTION_FEE) {
                revert Subscription__NotEnoughMoney(
                    token.balanceOf(msg.sender)
                );
            }

            token.approve(address(this), SUBSCRIPTION_FEE);
            token.safeTransferFrom(msg.sender, address(this), SUBSCRIPTION_FEE);

            s_subscriberToSubscription[msg.sender] = Subscriptions(
                paymentTokenForPrimaryChain,
                address(0),
                0
            );

            emit SubscriberToSubscriptionUpdated(
                msg.sender,
                paymentTokenForPrimaryChain,
                address(0),
                0
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) {
            revert Subscription__WithdrawFailed();
        }

        emit Withdrawn(address(0), address(this).balance);
    }

    function withdrawToken(address token) external onlyOwner {
        IERC20(token).safeTransfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );

        emit Withdrawn(token, IERC20(token).balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _isValidChain(uint64 chain) internal view returns (bool) {
        for (uint256 i = 0; i < s_subscriptionChainsSelector.length; i++) {
            if (s_subscriptionChainsSelector[i] == chain) {
                return true;
            }
        }
        return false;
    }

    function _chainlinkFunctionInfo(
        uint64 chainSelector
    ) internal pure returns (string memory chainBaseUrl) {
        if (chainSelector == SEPOLIA_CHAIN_SELECTOR) {
            chainBaseUrl = "eth-sepolia.blockscout.com";
        }
    }

    function _requestToCheckBalanceOnOptionalChain(
        address paymentTokenForOptionalChain,
        uint64 optionalChain
    ) internal {
        string memory chainBaseUrl = _chainlinkFunctionInfo(optionalChain);

        // send the request
        string[] memory args = new string[](3);
        args[0] = chainBaseUrl;
        args[1] = uint256(uint160(paymentTokenForOptionalChain)).toHexString();
        args[2] = uint256(uint160(msg.sender)).toHexString();
        CheckBalance checkBalance = CheckBalance(s_sepoliaCheckBalanceAddress);

        if (paymentTokenForOptionalChain == address(0)) {
            // if the token is native token
            checkBalance.sendRequest(true, SEPOLIA_SUBSCRIPTION_ID, args);
        } else {
            // if the token is not native token
            checkBalance.sendRequest(false, SEPOLIA_SUBSCRIPTION_ID, args);
        }
    }

    function _sendCCIPMessage(
        uint64 optionalChain,
        bytes memory signedMessage
    ) internal {
        s_sender.sendMessage(optionalChain, i_receiver, signedMessage);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getSubscriberToSubscription(
        address subscriber
    ) external view returns (Subscriptions memory) {
        return s_subscriberToSubscription[subscriber];
    }

    function getSubscriptionChainsSelector()
        external
        view
        returns (uint64[] memory)
    {
        return s_subscriptionChainsSelector;
    }

    function getAllowedToken() external view returns (address) {
        return s_allowedToken;
    }

    function getAllowedTokenForOptionalChain() external view returns (address) {
        return s_allowedTokenForOptionalChain;
    }

    function getSepoliaCheckBalanceAddress() external view returns (address) {
        return s_sepoliaCheckBalanceAddress;
    }

    function getSender() external view returns (Sender) {
        return s_sender;
    }

    function getSubscriptionFee() external pure returns (uint256) {
        return SUBSCRIPTION_FEE;
    }
}
