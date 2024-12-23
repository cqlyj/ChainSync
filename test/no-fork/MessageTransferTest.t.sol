// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {SepoliaSender} from "src/SepoliaSender.sol";
import {AmoyReceiver} from "src/AmoyReceiver.sol";
import {AmoyReceiverSignedMessage} from "src/library/AmoyReceiverSignedMessage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MessageTransferTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    uint64 public destinationChainSelector;
    BurnMintERC677Helper public CCIPBnM;

    SepoliaSender public sepoliaSender;
    AmoyReceiver public amoyReceiver;

    address user;
    uint256 userPrivateKey;

    uint256 constant AMOUNT_CCIPBNM = 1e18;
    IRouterClient destinationRouter;
    address linkAddress;

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

        sepoliaSender = new SepoliaSender(address(sourceRouter), address(link));
        vm.prank(user);
        amoyReceiver = new AmoyReceiver(
            address(destinationRouter),
            address(link)
        );
    }

    function testMessageTransferPass() public {
        ccipLocalSimulator.requestLinkFromFaucet(
            address(sepoliaSender),
            5 ether
        );

        ccipLocalSimulator.requestLinkFromFaucet(
            address(amoyReceiver),
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

        // vm.pauseGasMetering();
        bytes32 messageId = sepoliaSender.sendMessage(
            destinationChainSelector,
            address(amoyReceiver),
            encodedSignedMessage
        );

        bytes32 lastMessageId = amoyReceiver.getMessageId();
        bytes memory receivedMessage = amoyReceiver.getSignedMessage();

        assertEq(messageId, lastMessageId);
        assertEq(encodedSignedMessage, receivedMessage);
        assertEq(CCIPBnM.balanceOf(address(amoyReceiver)), 0);
        assertEq(CCIPBnM.balanceOf(user), AMOUNT_CCIPBNM);
    }

    function testOwnerCanWithdrawTheRestLink() public {
        ccipLocalSimulator.requestLinkFromFaucet(
            address(amoyReceiver),
            5 ether
        );

        assertEq(IERC20(linkAddress).balanceOf(address(amoyReceiver)), 5 ether);

        vm.prank(user);
        amoyReceiver.withdrawToken(user, linkAddress);
        assertEq(IERC20(linkAddress).balanceOf(user), 5 ether);
        assertEq(IERC20(linkAddress).balanceOf(address(amoyReceiver)), 0);
    }
}
