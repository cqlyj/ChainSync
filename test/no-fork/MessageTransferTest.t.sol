// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {SepoliaSender} from "src/SepoliaSender.sol";
import {AmoyReceiver} from "src/AmoyReceiver.sol";
import {AmoyReceiverSignedMessage} from "src/library/AmoyReceiverSignedMessage.sol";
import {AmoyTokenTransfer} from "src/AmoyTokenTransfer.sol";

contract MessageTransferTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    uint64 public destinationChainSelector;
    BurnMintERC677Helper public CCIPBnM;

    SepoliaSender public sepoliaSender;
    AmoyReceiver public amoyReceiver;
    AmoyTokenTransfer public amoyTokenTransfer;

    address user;
    uint256 userPrivateKey;

    uint256 constant AMOUNT_CCIPBNM = 1e18;
    IRouterClient destinationRouter;

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

        sepoliaSender = new SepoliaSender(address(sourceRouter), address(link));
        amoyTokenTransfer = new AmoyTokenTransfer(
            address(sourceRouter),
            address(link)
        );
        amoyReceiver = new AmoyReceiver(
            address(destinationRouter),
            address(amoyTokenTransfer)
        );
    }

    function testMessageTransferPassTheValidation() public {
        ccipLocalSimulator.requestLinkFromFaucet(
            address(sepoliaSender),
            5 ether
        );

        deal(address(CCIPBnM), user, AMOUNT_CCIPBNM);

        AmoyReceiverSignedMessage.SignedMessage
            memory signedMessage = AmoyReceiverSignedMessage.SignedMessage({
                chainSelector: destinationChainSelector,
                user: user,
                token: address(CCIPBnM),
                amount: AMOUNT_CCIPBNM,
                transferContract: address(amoyReceiver),
                router: address(destinationRouter),
                nonce: 0,
                expiry: block.timestamp + 1 days
            });

        bytes32 digest = amoyReceiver.getMessageHash(signedMessage);
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
        CCIPBnM.approve(address(amoyReceiver), AMOUNT_CCIPBNM);

        vm.pauseGasMetering();
        bytes32 messageId = sepoliaSender.sendMessage(
            destinationChainSelector,
            address(amoyReceiver),
            encodedSignedMessage
        );

        bytes32 lastMessageId = amoyReceiver.getMessageId();
        bytes memory receivedMessage = amoyReceiver.getSignedMessage();

        assertEq(messageId, lastMessageId);
        assertEq(encodedSignedMessage, receivedMessage);
    }
}
