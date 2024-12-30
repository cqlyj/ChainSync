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

    uint256 constant AMOUNT = 1e18;
    uint256 constant AMOUNT_CCIPBNM = 1e18;
    uint256 private constant SUBSCRIPTION_FEE = 1e16; // 0.01 ether
    // In the Receiver contract, the token is transferred to this address => The real owner of the Subscription contract
    // But here the owner is set to the user just for testing purpose
    address private immutable i_ownerAddress =
        0xFB6a372F2F51a002b390D18693075157A459641F;

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
                amount: SUBSCRIPTION_FEE,
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

        // The event MessageReceived is the 14th event
        uint64 optionalChain = uint64(uint256(entries[13].topics[1]));
        address paymentTokenForOptionalChain = bytes32ToAddress(
            entries[13].topics[2]
        );
        address signer = bytes32ToAddress(entries[13].topics[3]);

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

        // The subscription fee is transferred to the i_ownerAddress
        assertEq(
            IERC20(address(CCIPBnM)).balanceOf(i_ownerAddress),
            SUBSCRIPTION_FEE
        );
    }

    function testWithdrawNativeTokenAndTokenSuccess() public {
        vm.deal(user, AMOUNT);
        deal(address(CCIPBnM), user, AMOUNT_CCIPBNM);

        // 1. withdraw native token
        vm.prank(user);
        subscription.paySubscriptionFeeForPrimaryChain{value: AMOUNT}(
            address(0)
        );
        assertEq(address(subscription).balance, AMOUNT);
        assertEq(user.balance, 0);
        vm.prank(user);
        subscription.withdraw();
        assertEq(address(subscription).balance, 0);
        assertEq(user.balance, AMOUNT);

        // 2. withdraw token
        vm.startPrank(user);
        CCIPBnM.approve(address(subscription), AMOUNT_CCIPBNM);
        subscription.paySubscriptionFeeForPrimaryChain(address(CCIPBnM));
        vm.stopPrank();
        assertEq(
            IERC20(address(CCIPBnM)).balanceOf(address(subscription)),
            SUBSCRIPTION_FEE
        );
        assertEq(
            IERC20(address(CCIPBnM)).balanceOf(user),
            AMOUNT_CCIPBNM - SUBSCRIPTION_FEE
        );

        vm.prank(user);
        subscription.withdrawToken(address(CCIPBnM));

        assertEq(IERC20(address(CCIPBnM)).balanceOf(address(subscription)), 0);
        assertEq(IERC20(address(CCIPBnM)).balanceOf(user), AMOUNT_CCIPBNM);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function bytes32ToAddress(bytes32 _address) public pure returns (address) {
        return address(uint160(uint256(_address)));
    }
}
