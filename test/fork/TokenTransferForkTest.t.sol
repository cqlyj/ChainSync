// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {AmoyTokenTransfer} from "src/AmoyTokenTransfer.sol";
import {BurnMintERC677Helper, IERC20} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {TokenReceiverMock} from "test/mocks/TokenReceiverMock.sol";

contract TokenTransferForkTest is Test {
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint256 public sourceFork;
    uint256 public destinationFork;
    IRouterClient public sourceRouter;
    uint64 public destinationChainSelector;

    AmoyTokenTransfer public amoyTokenTransfer;
    TokenReceiverMock public tokenReceiverMock;
    IERC20 public sourceLinkToken;

    BurnMintERC677Helper public sourceCCIPBnM;
    BurnMintERC677Helper public destinationCCIPBnM;

    uint256 constant AMOUNT_LINK_REQUEST = 20 ether;
    uint256 constant AMOUNT_CCIPBNM = 1e18;

    address public USER = makeAddr("USER");

    function setUp() public {
        string memory SOURCE_RPC_URL = vm.envString("AMOY_RPC_URL");
        string memory DESTINATION_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
        sourceFork = vm.createFork(SOURCE_RPC_URL);
        destinationFork = vm.createSelectFork(DESTINATION_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.selectFork(sourceFork);
        Register.NetworkDetails
            memory sourceNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);
        sourceLinkToken = IERC20(sourceNetworkDetails.linkAddress);
        sourceCCIPBnM = BurnMintERC677Helper(
            sourceNetworkDetails.ccipBnMAddress
        );

        amoyTokenTransfer = new AmoyTokenTransfer(
            address(sourceRouter),
            address(sourceLinkToken)
        );

        deal(address(sourceCCIPBnM), USER, AMOUNT_CCIPBNM);

        vm.selectFork(destinationFork);
        Register.NetworkDetails
            memory destinationNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        destinationCCIPBnM = BurnMintERC677Helper(
            destinationNetworkDetails.ccipBnMAddress
        );
        tokenReceiverMock = new TokenReceiverMock();
    }

    function testTokenTransferForkSuccess() public {
        vm.selectFork(sourceFork);

        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(amoyTokenTransfer),
            AMOUNT_LINK_REQUEST
        );

        vm.startPrank(USER);
        sourceCCIPBnM.approve(address(amoyTokenTransfer), AMOUNT_CCIPBNM);
        sourceCCIPBnM.transfer(address(amoyTokenTransfer), AMOUNT_CCIPBNM);
        vm.stopPrank();

        vm.selectFork(destinationFork);
        Register.NetworkDetails
            memory destinationNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        destinationChainSelector = destinationNetworkDetails.chainSelector;

        vm.selectFork(sourceFork);

        amoyTokenTransfer.transferTokensPayLINK(
            destinationChainSelector,
            address(tokenReceiverMock),
            address(sourceCCIPBnM),
            AMOUNT_CCIPBNM
        );

        assertEq(sourceCCIPBnM.balanceOf(address(amoyTokenTransfer)), 0);
        assertEq(sourceCCIPBnM.balanceOf(USER), 0);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        vm.selectFork(destinationFork);
        assertEq(
            destinationCCIPBnM.balanceOf(address(tokenReceiverMock)),
            AMOUNT_CCIPBNM
        );
    }
}
