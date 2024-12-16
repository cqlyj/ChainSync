// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {SepoliaSender} from "src/SepoliaSender.sol";
import {AmoyReceiver} from "src/AmoyReceiver.sol";

contract MessageTransferForkTest is Test {
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint64 public destinationChainSelector;
    uint256 public sourceFork;
    uint256 public destinationFork;

    IRouterClient public sourceRouter;
    IRouterClient public destinationRouter;

    SepoliaSender public sepoliaSender;
    AmoyReceiver public amoyReceiver;

    function setUp() public {
        string memory SOURCE_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
        string memory DESTINATION_RPC_URL = vm.envString("AMOY_RPC_URL");
        sourceFork = vm.createFork(SOURCE_RPC_URL);
        destinationFork = vm.createSelectFork(DESTINATION_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.selectFork(sourceFork);
        Register.NetworkDetails
            memory sourceNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);

        sepoliaSender = new SepoliaSender(
            address(sourceRouter),
            address(sourceNetworkDetails.linkAddress)
        );

        vm.selectFork(destinationFork);
        Register.NetworkDetails
            memory destinationNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        destinationChainSelector = destinationNetworkDetails.chainSelector;
        destinationRouter = IRouterClient(
            destinationNetworkDetails.routerAddress
        );

        amoyReceiver = new AmoyReceiver(address(destinationRouter));
    }

    function testMessageTransferWithLinkTokenPaidFork() public {
        vm.selectFork(sourceFork);

        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(sepoliaSender),
            5 ether
        );

        bytes memory signedMessage = abi.encodePacked("Hello, Amoy!");

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Something wired here, the destinationChainSelector should be set in the setUp function and indeed set, but here it's still 0. //

        vm.selectFork(destinationFork);
        Register.NetworkDetails
            memory destinationNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        destinationChainSelector = destinationNetworkDetails.chainSelector;

        vm.selectFork(sourceFork);

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        bytes32 messageId = sepoliaSender.sendMessage(
            destinationChainSelector,
            address(amoyReceiver),
            signedMessage
        );

        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        vm.selectFork(destinationFork);
        bytes memory receivedMessage = amoyReceiver.getSignedMessage();
        bytes32 lastMessageId = amoyReceiver.getMessageId();

        string memory expectedMessage = "Hello, Amoy!";
        string memory actualMessage = abi.decode(receivedMessage, (string));

        assertEq(messageId, lastMessageId);
        assertEq(expectedMessage, actualMessage);
    }
}
