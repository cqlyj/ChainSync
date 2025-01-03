// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title CheckBalance
/// @author Luo Yingjie
/// @notice This contract will check the balance of a subscriber's account for a given token
/// @notice This contract is meant to send the API request to Blockscout service and get the balance on the optional chain
/// @dev This contract will be deployed on the primary chain same as the Subscription contract
contract CheckBalance is FunctionsClient, Ownable {
    using FunctionsRequest for FunctionsRequest.Request;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 private s_lastRequestId;
    bytes private s_lastResponse;
    bytes private s_lastError;
    uint32 private constant GASLIMIT = 300000;
    bytes32 private s_donID;
    string private s_sourceForAllowedToken =
        "const chainBaseUrl = args[0];"
        "const tokenAddress = args[1];"
        "const subscriber = args[2];"
        "const apiResponse = await Functions.makeHttpRequest({"
        " url: `https://${chainBaseUrl}//api?module=account&action=tokenbalance&contractaddress=${tokenAddress}&address=${subscriber}`"
        "});"
        "if (apiResponse.error) {"
        "throw Error('Request failed');"
        "}"
        "const { data } = apiResponse;"
        "return Functions.encodeString(data.result);";

    string private s_sourceForNativeToken =
        "const chainBaseUrl = args[0];"
        "const subscriber = args[1];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "  url: `https://${chainBaseUrl}/api?module=account&action=eth_get_balance&address=${subscriber}`"
        "});"
        "if (apiResponse.error) {"
        "throw Error('Request failed');"
        "}"
        "const { data } = apiResponse;"
        "return Functions.encodeString(data.result);";
    uint256 private s_balance;
    bool private s_initialized;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnexpectedRequestID(bytes32 requestId);
    error CheckBalance__AlreadyInitialized();
    error CheckBalance__NotInitialized();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Response(
        bytes32 indexed requestId,
        bytes response,
        bytes err,
        uint256 indexed balance
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier initializedOnlyOnce() {
        if (s_initialized) {
            revert CheckBalance__AlreadyInitialized();
        }
        _;
    }

    modifier hasInitialized() {
        if (!s_initialized) {
            revert CheckBalance__NotInitialized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address router,
        bytes32 donID
    ) FunctionsClient(router) Ownable(msg.sender) {
        s_donID = donID;
        s_initialized = false;
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setSubscriptionAsOwner(
        address subscription
    ) external onlyOwner initializedOnlyOnce {
        transferOwnership(subscription);
        s_initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                           OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function sendRequest(
        bool isNativeToken,
        uint64 subscriptionId,
        string[] calldata args
    ) external onlyOwner hasInitialized returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        if (isNativeToken) {
            req.initializeRequestForInlineJavaScript(s_sourceForNativeToken); // Initialize the request with JS code
        } else {
            req.initializeRequestForInlineJavaScript(s_sourceForAllowedToken); // Initialize the request with JS code
        }
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            GASLIMIT,
            s_donID
        );

        return s_lastRequestId;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }
        // Update the contract's state variables with the response and any errors
        s_lastResponse = response;
        s_lastError = err;
        string memory balanceString = string(response);
        s_balance = stringToUint256(balanceString);

        // Emit an event to log the response
        emit Response(requestId, s_lastResponse, s_lastError, s_balance);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function stringToUint256(
        string memory s
    ) public pure returns (uint256 result) {
        bytes memory b = bytes(s);
        uint256 i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getResponse() external view returns (bytes memory) {
        return s_lastResponse;
    }

    function getLastError() external view returns (bytes memory) {
        return s_lastError;
    }

    function getBalance() external view returns (uint256) {
        return s_balance;
    }
}
