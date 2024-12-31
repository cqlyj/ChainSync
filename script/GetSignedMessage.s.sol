// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Receiver} from "../src/Receiver.sol";
import {ReceiverSignedMessage} from "src/library/ReceiverSignedMessage.sol";

contract GetSignedMessage is Script {
    Receiver receiver;

    address public constant SEPOLIA_CCIPBNM =
        0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05;
    uint64 public constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    address public constant SEPOLIA_ROUTER =
        0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    uint256 public constant SUBSCRIPTION_FEE = 1e16;

    // @notice update to your owner burner wallet address
    address constant BURNER_WALLET = 0xFB6a372F2F51a002b390D18693075157A459641F;

    function getSignedMessage() public view {
        ReceiverSignedMessage.SignedMessage memory signedMessage = ReceiverSignedMessage
            .SignedMessage({
                chainSelector: SEPOLIA_CHAIN_SELECTOR,
                user: BURNER_WALLET,
                token: SEPOLIA_CCIPBNM,
                amount: SUBSCRIPTION_FEE,
                transferContract: address(receiver),
                router: address(SEPOLIA_ROUTER),
                // @notice update the nonce if you try to send a new message!!!
                nonce: 0,
                // Set the expiry to 1 day later from now so that the message is valid for 1 day
                expiry: block.timestamp + 1 days
            });

        bytes32 digest = receiver.getMessageHash(signedMessage);
        console.logBytes32(digest);
        // Sign this with the help of cast wallet sign...
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(BURNER_WALLET, digest);
        bytes memory encodedSignedMessage = abi.encode(
            BURNER_WALLET,
            signedMessage,
            v,
            r,
            s
        );

        console.logBytes(encodedSignedMessage);
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Receiver",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);

        receiver = Receiver(payable(mostRecentlyDeployed));

        getSignedMessage();
    }
}
