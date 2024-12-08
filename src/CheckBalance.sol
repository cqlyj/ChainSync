// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract CheckBalance is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 private s_lastRequestId;
    uint256 private s_lastResponse;
    bytes private s_lastError;
    uint32 private s_gasLimit = 300000;
    bytes32 private s_donID;
    string private s_chainBaseUrl;
    address private s_tokenAddress;
    address private s_subscriber;
    string private s_source =
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

    error UnexpectedRequestID(bytes32 requestId);

    event Response(bytes32 indexed requestId, uint256 response, bytes err);

    constructor(
        string memory _chainBaseUrl,
        address _tokenAddress,
        address _subscriber,
        address router,
        bytes32 donID
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        s_chainBaseUrl = _chainBaseUrl;
        s_tokenAddress = _tokenAddress;
        s_subscriber = _subscriber;
        s_donID = donID;
    }

    /*//////////////////////////////////////////////////////////////
                           OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function sendRequest(
        uint64 subscriptionId,
        string[] calldata args
    ) external onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            s_gasLimit,
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
        s_lastResponse = abi.decode(response, (uint256));
        s_lastError = err;

        // Emit an event to log the response
        emit Response(requestId, s_lastResponse, s_lastError);
    }

    function getResponse() external view returns (uint256) {
        return s_lastResponse;
    }

    function getLastError() external view returns (bytes memory) {
        return s_lastError;
    }
}
