// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {AmoyTokenTransfer} from "src/AmoyTokenTransfer.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {TokenReceiverMock} from "test/no-fork/mocks/TokenReceiverMock.sol";

contract TokenTransferTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    uint64 public destinationChainSelector;
    AmoyTokenTransfer public amoyTokenTransfer;
    TokenReceiverMock public tokenReceiverMock;
    BurnMintERC677Helper public CCIPBnM;

    uint256 constant AMOUNT_LINK_REQUEST = 20 ether;
    uint256 constant AMOUNT_CCIPBNM = 1e18;

    address public USER = makeAddr("USER");

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();
        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            ,
            ,
            LinkToken linkToken,
            BurnMintERC677Helper ccipBnM,

        ) = ccipLocalSimulator.configuration();

        destinationChainSelector = chainSelector;
        CCIPBnM = ccipBnM;

        amoyTokenTransfer = new AmoyTokenTransfer(
            address(sourceRouter),
            address(linkToken)
        );

        tokenReceiverMock = new TokenReceiverMock();
        deal(address(CCIPBnM), USER, AMOUNT_CCIPBNM);
    }

    function testTransferTokenSuccess() public {
        ccipLocalSimulator.requestLinkFromFaucet(
            address(amoyTokenTransfer),
            AMOUNT_LINK_REQUEST
        );

        vm.startPrank(USER);
        CCIPBnM.approve(address(amoyTokenTransfer), AMOUNT_CCIPBNM);
        CCIPBnM.transfer(address(amoyTokenTransfer), AMOUNT_CCIPBNM);
        vm.stopPrank();

        amoyTokenTransfer.transferTokensPayLINK(
            destinationChainSelector,
            address(tokenReceiverMock),
            address(CCIPBnM),
            AMOUNT_CCIPBNM
        );

        assertEq(CCIPBnM.balanceOf(address(tokenReceiverMock)), AMOUNT_CCIPBNM);
        assertEq(CCIPBnM.balanceOf(address(amoyTokenTransfer)), 0);
        assertEq(CCIPBnM.balanceOf(USER), 0);
    }
}
