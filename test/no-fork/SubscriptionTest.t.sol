// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {Subscription} from "src/Subscription.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Sender} from "src/Sender.sol";
import {Receiver} from "src/Receiver.sol";
import {ReceiverSignedMessage} from "src/library/ReceiverSignedMessage.sol";
import {MockCheckBalance} from "test/mocks/MockCheckBalance.sol";
import {Vm} from "forge-std/Vm.sol";
import {Relayer} from "src/Relayer.sol";

contract SubscriptionTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    uint64 public destinationChainSelector;
    BurnMintERC677Helper public CCIPBnM;
    address user;
    uint256 userPrivateKey;

    uint256 constant AMOUNT_CCIPBNM = 1e18;
    IRouterClient destinationRouter;
    address linkAddress;

    Subscription public subscription;
    // To simulate the check balance contracts
    MockCheckBalance public checkBalance;
    Sender public sender;
    Receiver public receiver;
    Relayer public relayer;

    function setUp() public {
        (user, userPrivateKey) = makeAddrAndKey("user");
        ccipLocalSimulator = new CCIPLocalSimulator();

        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient _destinationRouter,
            ,
            LinkToken link,
            BurnMintERC677Helper ccipBnM,

        ) = ccipLocalSimulator.configuration();

        destinationChainSelector = chainSelector;
        CCIPBnM = ccipBnM;
        destinationRouter = _destinationRouter;
        linkAddress = address(link);

        uint64[] memory subscriptionChainsSelector = new uint64[](1);
        subscriptionChainsSelector[0] = destinationChainSelector;

        vm.startPrank(user);
        checkBalance = new MockCheckBalance();
        sender = new Sender(address(sourceRouter), linkAddress);
        receiver = new Receiver(address(destinationRouter), linkAddress);
        subscription = new Subscription(
            subscriptionChainsSelector,
            address(CCIPBnM),
            address(CCIPBnM),
            address(sourceRouter),
            address(checkBalance),
            address(sender),
            address(receiver)
        );
        relayer = new Relayer(
            address(destinationRouter),
            linkAddress,
            address(subscription)
        );

        // transfer the ownership to subscription contract first as the set up
        checkBalance.setSubscriptionAsOwner(address(subscription));
        sender.setSubscriptionAsOwner(address(subscription));
        vm.stopPrank();
    }

    function testPaySubscriptionFeeforOptionalChainSuccessUpdateTheMapping()
        public
    {
        ccipLocalSimulator.requestLinkFromFaucet(address(sender), 20 ether);
        ccipLocalSimulator.requestLinkFromFaucet(address(receiver), 20 ether);

        deal(address(CCIPBnM), user, AMOUNT_CCIPBNM);

        ReceiverSignedMessage.SignedMessage
            memory signedMessage = ReceiverSignedMessage.SignedMessage({
                chainSelector: destinationChainSelector,
                user: user,
                token: address(CCIPBnM),
                amount: AMOUNT_CCIPBNM,
                transferContract: address(receiver),
                router: address(destinationRouter),
                nonce: 0,
                expiry: block.timestamp + 1 days
            });

        bytes32 digest = receiver.getMessageHash(signedMessage);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        bytes memory encodedSignedMessage = abi.encode(
            user,
            signedMessage,
            v,
            r,
            s
        );

        // approve the transfer first
        vm.prank(user);
        CCIPBnM.approve(address(receiver), AMOUNT_CCIPBNM);

        // 1. token transferred
        vm.recordLogs();
        subscription.paySubscriptionFeeforOptionalChain(
            address(CCIPBnM),
            destinationChainSelector,
            encodedSignedMessage
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // The event MessageReceived is the 13th event
        uint64 optionalChain = uint64(uint256(entries[12].topics[1]));
        address paymentTokenForOptionalChain = bytes32ToAddress(
            entries[12].topics[2]
        );
        address signer = bytes32ToAddress(entries[12].topics[3]);

        assertEq(optionalChain, destinationChainSelector);
        assertEq(paymentTokenForOptionalChain, address(CCIPBnM));
        assertEq(signer, user);

        // 2. The Relayer listen for MessageReceived event and send the message to the Subscription contract
        bytes memory performData = abi.encode(
            optionalChain,
            paymentTokenForOptionalChain,
            signer
        );

        relayer.performUpkeep(performData);

        // 3. The Subscription contract receives the message and update the s_subscriberToSubscription mapping
        assertEq(
            subscription.getSubscriberToSubscription(user).optionalChain,
            destinationChainSelector
        );
        assertEq(
            subscription
                .getSubscriberToSubscription(user)
                .paymentTokenForOptionalChain,
            address(CCIPBnM)
        );
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function bytes32ToAddress(bytes32 _address) public pure returns (address) {
        return address(uint160(uint256(_address)));
    }
}
