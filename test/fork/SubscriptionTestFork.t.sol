// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {BurnMintERC677Helper, IERC20} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {Receiver} from "src/Receiver.sol";
import {Sender} from "src/Sender.sol";
import {MockCheckBalance} from "test/mocks/MockCheckBalance.sol";
import {Subscription} from "src/Subscription.sol";
import {Relayer} from "src/Relayer.sol";
import {ReceiverSignedMessage} from "src/library/ReceiverSignedMessage.sol";
import {Vm} from "forge-std/Vm.sol";

/// @title SubscriptionTestFork
/// @author Luo Yingjie
/// @notice This is the fork local test of the Subscription contract
/// @dev The contracts on the source chain are Sender, CheckBalance(Mock one), Subscription
/// @dev The contracts on the destination chain are Receiver and Relayer
contract SubscriptionTestFork is Test {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint256 public sourceFork;
    uint256 public destinationFork;

    IRouterClient public sourceRouter;
    IERC20 public sourceLinkToken;
    BurnMintERC677Helper public sourceCCIPBnM;

    IRouterClient public destinationRouter;
    IERC20 public destinationLinkToken;
    BurnMintERC677Helper public destinationCCIPBnM;
    uint64 public destinationChainSelector;

    Receiver public receiver;
    Sender public sender;
    MockCheckBalance public checkBalance;
    Subscription public subscription;
    Relayer public relayer;

    address user;
    uint256 userPrivateKey;

    uint256 constant AMOUNT_DESTINATION_CCIPBNM = 1e18;
    // The amount of LINK required to make a request
    uint256 constant AMOUNT_LINK_REQUEST = 20 ether;
    uint256 constant AMOUNT_CCIPBNM_TO_TRANSFER = 1e16;
    // native token amount
    uint256 constant AMOUNT = 1e18;
    // In the Receiver contract, the token is transferred to this address => The real owner of the Subscription contract
    // But here the owner is set to the user just for testing purpose
    address private immutable i_ownerAddress =
        0xFB6a372F2F51a002b390D18693075157A459641F;

    /*//////////////////////////////////////////////////////////////
                            SET UP FUNCTION
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        (user, userPrivateKey) = makeAddrAndKey("user");

        string memory SOURCE_RPC_URL = vm.envString("AMOY_RPC_URL");
        string memory DESTINATION_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
        sourceFork = vm.createFork(SOURCE_RPC_URL);
        destinationFork = vm.createSelectFork(DESTINATION_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // First deploy the destination chain contracts => Receiver
        vm.selectFork(destinationFork);
        Register.NetworkDetails
            memory destinationNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        destinationRouter = IRouterClient(
            destinationNetworkDetails.routerAddress
        );
        destinationLinkToken = IERC20(destinationNetworkDetails.linkAddress);
        destinationCCIPBnM = BurnMintERC677Helper(
            destinationNetworkDetails.ccipBnMAddress
        );
        destinationChainSelector = destinationNetworkDetails.chainSelector;

        // deal some CCIPBnM to the user
        deal(address(destinationCCIPBnM), user, AMOUNT_DESTINATION_CCIPBNM);

        vm.prank(user);
        receiver = new Receiver(
            address(destinationRouter),
            address(destinationLinkToken)
        );

        // Then deploy the source chain contracts => Sender, CheckBalance, Subscription
        vm.selectFork(sourceFork);
        Register.NetworkDetails
            memory sourceNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);
        sourceLinkToken = IERC20(sourceNetworkDetails.linkAddress);
        sourceCCIPBnM = BurnMintERC677Helper(
            sourceNetworkDetails.ccipBnMAddress
        );

        vm.startPrank(user);
        sender = new Sender(address(sourceRouter), address(sourceLinkToken));
        checkBalance = new MockCheckBalance();

        uint64[] memory destinationChainSelectors = new uint64[](1);
        destinationChainSelectors[0] = destinationChainSelector;
        subscription = new Subscription(
            destinationChainSelectors,
            address(sourceCCIPBnM),
            address(destinationCCIPBnM),
            address(sourceRouter),
            address(checkBalance),
            address(sender),
            address(receiver)
        );
        // transfer the ownership to subscription contract first as the set up
        checkBalance.setSubscriptionAsOwner(address(subscription));
        sender.setSubscriptionAsOwner(address(subscription));
        vm.stopPrank();

        // And lastly deploy the Relay contract on destination chain
        vm.selectFork(destinationFork);
        vm.prank(user);
        relayer = new Relayer(
            address(destinationRouter),
            address(destinationLinkToken),
            address(subscription)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function testPaySubscriptionFeeforOptionalChainSuccessUpdateTheMappingFork()
        public
    {
        // First, we need to request some LINK from the faucet
        vm.selectFork(sourceFork);
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(sender),
            AMOUNT_LINK_REQUEST
        );

        vm.selectFork(destinationFork);
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(receiver),
            AMOUNT_LINK_REQUEST
        );
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(relayer),
            AMOUNT_LINK_REQUEST
        );

        // approve the Receiver to spend the user's CCIPBnM
        vm.prank(user);
        destinationCCIPBnM.approve(
            address(receiver),
            AMOUNT_CCIPBNM_TO_TRANSFER
        );

        // Sign the message with the user's private key
        ReceiverSignedMessage.SignedMessage memory signedMessage = ReceiverSignedMessage
            .SignedMessage({
                chainSelector: destinationChainSelector,
                user: user,
                token: address(destinationCCIPBnM),
                amount: AMOUNT_CCIPBNM_TO_TRANSFER,
                transferContract: address(receiver),
                router: address(destinationRouter),
                // For test just set the nonce to 0
                nonce: 0,
                // Set the expiry to 1 day later from now
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

        // call the paySubscriptionFeeforOptionalChain function
        // it will first call the checkBalance contract to check the balance
        // then it will call the send function in Sender to route the message to the Receiver
        vm.selectFork(sourceFork);
        vm.startPrank(user);
        vm.recordLogs();
        subscription.paySubscriptionFeeforOptionalChain(
            address(destinationCCIPBnM),
            destinationChainSelector,
            encodedSignedMessage
        );

        // switch the chain and route the message
        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.log(entries.length);
        // The event MessageReceived is the 17th event
        uint64 optionalChain = uint64(uint256(entries[16].topics[1]));
        address paymentTokenForOptionalChain = bytes32ToAddress(
            entries[16].topics[2]
        );
        address signer = bytes32ToAddress(entries[16].topics[3]);

        assertEq(optionalChain, destinationChainSelector);
        assertEq(paymentTokenForOptionalChain, address(destinationCCIPBnM));
        assertEq(signer, user);
        vm.stopPrank();

        // 2. The Relayer listen for MessageReceived event and send the message to the Subscription contract
        vm.selectFork(destinationFork);
        bytes memory performData = abi.encode(
            optionalChain,
            paymentTokenForOptionalChain,
            signer
        );
        relayer.performUpkeep(performData);

        // switch the chain and route the message
        ccipLocalSimulatorFork.switchChainAndRouteMessage(sourceFork);

        // 3. The Subscription contract receives the message and update the s_subscriberToSubscription mapping
        vm.selectFork(sourceFork);
        assertEq(
            subscription.getSubscriberToSubscription(user).optionalChain,
            destinationChainSelector
        );
        assertEq(
            subscription
                .getSubscriberToSubscription(user)
                .paymentTokenForOptionalChain,
            address(destinationCCIPBnM)
        );
        // @notice here this fork test will grab the original owner balance and compare, so we just comment out this line in fork test
        // @notice we still assert this line of code in the no-fork test

        // The subscription fee is transferred to the i_ownerAddress
        // assertEq(
        //     IERC20(address(sourceCCIPBnM)).balanceOf(i_ownerAddress),
        //     AMOUNT_CCIPBNM_TO_TRANSFER
        // );
    }

    function testWithdrawNativeTokenAndTokenSuccessFork() public {
        // 1. withdraw native token
        vm.selectFork(sourceFork);
        vm.deal(user, AMOUNT);
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
        deal(address(sourceCCIPBnM), user, AMOUNT_DESTINATION_CCIPBNM);
        sourceCCIPBnM.approve(
            address(subscription),
            AMOUNT_CCIPBNM_TO_TRANSFER
        );
        subscription.paySubscriptionFeeForPrimaryChain(address(sourceCCIPBnM));
        vm.stopPrank();
        assertEq(
            IERC20(address(sourceCCIPBnM)).balanceOf(address(subscription)),
            AMOUNT_CCIPBNM_TO_TRANSFER
        );
        assertEq(
            IERC20(address(sourceCCIPBnM)).balanceOf(user),
            AMOUNT_DESTINATION_CCIPBNM - AMOUNT_CCIPBNM_TO_TRANSFER
        );

        vm.prank(user);
        subscription.withdrawToken(address(sourceCCIPBnM));

        assertEq(
            IERC20(address(sourceCCIPBnM)).balanceOf(address(subscription)),
            0
        );
        assertEq(
            IERC20(address(sourceCCIPBnM)).balanceOf(user),
            AMOUNT_DESTINATION_CCIPBNM
        );
    }

    function testPaySubscriptionFeeforOptionalChainRevertIfInvalidSignatureFork()
        public
    {
        // First, we need to request some LINK from the faucet
        vm.selectFork(sourceFork);
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(sender),
            AMOUNT_LINK_REQUEST
        );

        vm.selectFork(destinationFork);
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(receiver),
            AMOUNT_LINK_REQUEST
        );
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(relayer),
            AMOUNT_LINK_REQUEST
        );

        // approve the Receiver to spend the user's CCIPBnM
        vm.prank(user);
        destinationCCIPBnM.approve(
            address(receiver),
            AMOUNT_CCIPBNM_TO_TRANSFER
        );

        // Sign the message with the user's private key
        ReceiverSignedMessage.SignedMessage memory signedMessage = ReceiverSignedMessage
            .SignedMessage({
                chainSelector: destinationChainSelector,
                user: user,
                token: address(destinationCCIPBnM),
                amount: AMOUNT_CCIPBNM_TO_TRANSFER,
                transferContract: address(receiver),
                router: address(destinationRouter),
                // We set the nonce to 1, whcih is wrong, it should be 0
                nonce: 1,
                // Set the expiry to 1 day later from now
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

        vm.selectFork(sourceFork);
        vm.startPrank(user);
        subscription.paySubscriptionFeeforOptionalChain(
            address(destinationCCIPBnM),
            destinationChainSelector,
            encodedSignedMessage
        );
        vm.expectRevert();
        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function bytes32ToAddress(bytes32 _address) public pure returns (address) {
        return address(uint160(uint256(_address)));
    }
}
