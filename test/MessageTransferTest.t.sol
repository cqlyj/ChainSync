// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {SepoliaSender} from "src/SepoliaSender.sol";
import {AmoyReceiver} from "src/AmoyReceiver.sol";

contract MessageTransferTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    uint64 public destinationChainSelector;

    SepoliaSender public sepoliaSender;
    AmoyReceiver public amoyReceiver;

    address public USER = makeAddr("USER");

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();

        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            ,
            LinkToken link,
            ,

        ) = ccipLocalSimulator.configuration();

        destinationChainSelector = chainSelector;

        sepoliaSender = new SepoliaSender(address(sourceRouter), address(link));
        amoyReceiver = new AmoyReceiver(address(destinationRouter));
    }

    function testMessageTransferWithLinkTokenPaid() public {
        ccipLocalSimulator.requestLinkFromFaucet(
            address(sepoliaSender),
            5 ether
        );

        bytes memory signedMessage = abi.encodePacked("Hello, Amoy!");

        bytes32 messageId = sepoliaSender.sendMessage(
            destinationChainSelector,
            address(amoyReceiver),
            signedMessage
        );

        bytes memory receivedMessage = amoyReceiver.getSignedMessage();
        bytes32 lastMessageId = amoyReceiver.getMessageId();

        string memory expectedMessage = "Hello, Amoy!";
        string memory actualMessage = abi.decode(receivedMessage, (string));

        assertEq(messageId, lastMessageId);
        assertEq(expectedMessage, actualMessage);
    }
}
