# Aderyn Analysis Report

This report was generated by [Aderyn](https://github.com/Cyfrin/aderyn), a static analysis tool built by [Cyfrin](https://cyfrin.io), a blockchain security company. This report is not a substitute for manual audit or security review. It should not be relied upon for any purpose other than to assist in the identification of potential security vulnerabilities.

# Table of Contents

- [Aderyn Analysis Report](#aderyn-analysis-report)
- [Table of Contents](#table-of-contents)
- [Summary](#summary)
	- [Files Summary](#files-summary)
	- [Files Details](#files-details)
	- [Issue Summary](#issue-summary)
- [High Issues](#high-issues)
	- [H-1: Arbitrary `from` passed to `transferFrom` (or `safeTransferFrom`)](#h-1-arbitrary-from-passed-to-transferfrom-or-safetransferfrom)
	- [H-2: Functions send eth away from contract but performs no checks on any address.](#h-2-functions-send-eth-away-from-contract-but-performs-no-checks-on-any-address)
	- [H-3: Return value of the function call is not checked.](#h-3-return-value-of-the-function-call-is-not-checked)
	- [H-4: Contract locks Ether without a withdraw function.](#h-4-contract-locks-ether-without-a-withdraw-function)
- [Low Issues](#low-issues)
	- [L-1: Centralization Risk for trusted owners](#l-1-centralization-risk-for-trusted-owners)
	- [L-2: Unsafe ERC20 Operations should not be used](#l-2-unsafe-erc20-operations-should-not-be-used)
	- [L-3: Missing checks for `address(0)` when assigning values to address state variables](#l-3-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
	- [L-4: `public` functions not used internally could be marked `external`](#l-4-public-functions-not-used-internally-could-be-marked-external)
	- [L-5: Define and use `constant` variables instead of using literals](#l-5-define-and-use-constant-variables-instead-of-using-literals)
	- [L-6: Event is missing `indexed` fields](#l-6-event-is-missing-indexed-fields)
	- [L-7: Modifiers invoked only once can be shoe-horned into the function](#l-7-modifiers-invoked-only-once-can-be-shoe-horned-into-the-function)
	- [L-8: Large literal values multiples of 10000 can be replaced with scientific notation](#l-8-large-literal-values-multiples-of-10000-can-be-replaced-with-scientific-notation)
	- [L-9: Internal functions called only once can be inlined](#l-9-internal-functions-called-only-once-can-be-inlined)
	- [L-10: Unused Custom Error](#l-10-unused-custom-error)
	- [L-11: Loop condition contains `state_variable.length` that could be cached outside.](#l-11-loop-condition-contains-state_variablelength-that-could-be-cached-outside)
	- [L-12: Unused Imports](#l-12-unused-imports)
	- [L-13: State variable could be declared constant](#l-13-state-variable-could-be-declared-constant)
	- [L-14: State variable changes but no event is emitted.](#l-14-state-variable-changes-but-no-event-is-emitted)
	- [L-15: State variable could be declared immutable](#l-15-state-variable-could-be-declared-immutable)

# Summary

## Files Summary

| Key         | Value |
| ----------- | ----- |
| .sol Files  | 7     |
| Total nSLOC | 822   |

## Files Details

| Filepath                              | nSLOC   |
| ------------------------------------- | ------- |
| src/CheckBalance.sol                  | 127     |
| src/Receiver.sol                      | 250     |
| src/Relayer.sol                       | 82      |
| src/Sender.sol                        | 85      |
| src/Subscription.sol                  | 247     |
| src/interfaces/ILogAutomation.sol     | 18      |
| src/library/ReceiverSignedMessage.sol | 13      |
| **Total**                             | **822** |

## Issue Summary

| Category | No. of Issues |
| -------- | ------------- |
| High     | 4             |
| Low      | 15            |

# High Issues

## H-1: Arbitrary `from` passed to `transferFrom` (or `safeTransferFrom`)

Passing an arbitrary `from` address to `transferFrom` (or `safeTransferFrom`) can lead to loss of funds, because anyone can transfer tokens from the `from` address if an approval is made.

<details><summary>1 Found Instances</summary>

- Found in src/Receiver.sol [Line: 247](src/Receiver.sol#L247)

  ```solidity
          IERC20(signedMessage.token).safeTransferFrom(
  ```

</details>

## H-2: Functions send eth away from contract but performs no checks on any address.

Consider introducing checks for `msg.sender` to ensure the recipient of the money is as intended.

<details><summary>1 Found Instances</summary>

- Found in src/Subscription.sol [Line: 264](src/Subscription.sol#L264)

  ```solidity
      function withdraw() external onlyOwner {
  ```

</details>

## H-3: Return value of the function call is not checked.

Function returns a value but it is ignored.

<details><summary>5 Found Instances</summary>

- Found in src/Receiver.sol [Line: 254](src/Receiver.sol#L254)

  ```solidity
          transferTokensPayLINK(
  ```

- Found in src/Relayer.sol [Line: 81](src/Relayer.sol#L81)

  ```solidity
          sendMessage(i_subscriptionAddress, performData);
  ```

- Found in src/Subscription.sol [Line: 318](src/Subscription.sol#L318)

  ```solidity
              checkBalance.sendRequest(true, AMOY_SUBSCRIPTION_ID, args);
  ```

- Found in src/Subscription.sol [Line: 321](src/Subscription.sol#L321)

  ```solidity
              checkBalance.sendRequest(false, AMOY_SUBSCRIPTION_ID, args);
  ```

- Found in src/Subscription.sol [Line: 329](src/Subscription.sol#L329)

  ```solidity
          s_sender.sendMessage(optionalChain, i_receiver, signedMessage);
  ```

</details>

## H-4: Contract locks Ether without a withdraw function.

It appears that the contract includes a payable function to accept Ether but lacks a corresponding function to withdraw it, which leads to the Ether being locked in the contract. To resolve this issue, please implement a public or external function that allows for the withdrawal of Ether from the contract.

<details><summary>1 Found Instances</summary>

- Found in src/Receiver.sol [Line: 18](src/Receiver.sol#L18)

  ```solidity
  contract Receiver is CCIPReceiver, EIP712, OwnerIsCreator {
  ```

</details>

# Low Issues

## L-1: Centralization Risk for trusted owners

Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

<details><summary>10 Found Instances</summary>

- Found in src/CheckBalance.sol [Line: 13](src/CheckBalance.sol#L13)

  ```solidity
  contract CheckBalance is FunctionsClient, Ownable {
  ```

- Found in src/CheckBalance.sol [Line: 107](src/CheckBalance.sol#L107)

  ```solidity
      ) external onlyOwner initializedOnlyOnce {
  ```

- Found in src/CheckBalance.sol [Line: 120](src/CheckBalance.sol#L120)

  ```solidity
      ) external onlyOwner hasInitialized returns (bytes32 requestId) {
  ```

- Found in src/Receiver.sol [Line: 134](src/Receiver.sol#L134)

  ```solidity
      ) public onlyOwner {
  ```

- Found in src/Sender.sol [Line: 13](src/Sender.sol#L13)

  ```solidity
  contract Sender is Ownable {
  ```

- Found in src/Sender.sol [Line: 85](src/Sender.sol#L85)

  ```solidity
      ) external onlyOwner initializedOnlyOnce {
  ```

- Found in src/Sender.sol [Line: 99](src/Sender.sol#L99)

  ```solidity
      ) external onlyOwner hasInitialized returns (bytes32 messageId) {
  ```

- Found in src/Subscription.sol [Line: 20](src/Subscription.sol#L20)

  ```solidity
  contract Subscription is ILogAutomation, CCIPReceiver, Ownable {
  ```

- Found in src/Subscription.sol [Line: 264](src/Subscription.sol#L264)

  ```solidity
      function withdraw() external onlyOwner {
  ```

- Found in src/Subscription.sol [Line: 273](src/Subscription.sol#L273)

  ```solidity
      function withdrawToken(address token) external onlyOwner {
  ```

</details>

## L-2: Unsafe ERC20 Operations should not be used

ERC20 functions may not behave as expected. For example: return values are not always meaningful. It is recommended to use OpenZeppelin's SafeERC20 library.

<details><summary>5 Found Instances</summary>

- Found in src/Receiver.sol [Line: 176](src/Receiver.sol#L176)

  ```solidity
          s_linkToken.approve(address(s_router), fees);
  ```

- Found in src/Receiver.sol [Line: 179](src/Receiver.sol#L179)

  ```solidity
          IERC20(_token).approve(address(s_router), _amount);
  ```

- Found in src/Relayer.sol [Line: 121](src/Relayer.sol#L121)

  ```solidity
          s_linkToken.approve(address(s_router), fees);
  ```

- Found in src/Sender.sol [Line: 132](src/Sender.sol#L132)

  ```solidity
          s_linkToken.approve(address(s_router), fees);
  ```

- Found in src/Subscription.sol [Line: 242](src/Subscription.sol#L242)

  ```solidity
              token.approve(address(this), SUBSCRIPTION_FEE);
  ```

</details>

## L-3: Missing checks for `address(0)` when assigning values to address state variables

Check for `address(0)` when assigning values to address state variables.

<details><summary>11 Found Instances</summary>

- Found in src/Receiver.sol [Line: 110](src/Receiver.sol#L110)

  ```solidity
          s_router = IRouterClient(_router);
  ```

- Found in src/Receiver.sol [Line: 111](src/Receiver.sol#L111)

  ```solidity
          s_linkToken = IERC20(_link);
  ```

- Found in src/Relayer.sol [Line: 55](src/Relayer.sol#L55)

  ```solidity
          s_router = IRouterClient(_router);
  ```

- Found in src/Relayer.sol [Line: 56](src/Relayer.sol#L56)

  ```solidity
          s_linkToken = LinkTokenInterface(_link);
  ```

- Found in src/Sender.sol [Line: 74](src/Sender.sol#L74)

  ```solidity
          s_router = IRouterClient(_router);
  ```

- Found in src/Sender.sol [Line: 75](src/Sender.sol#L75)

  ```solidity
          s_linkToken = LinkTokenInterface(_link);
  ```

- Found in src/Subscription.sol [Line: 88](src/Subscription.sol#L88)

  ```solidity
          s_allowedToken = _allowedToken;
  ```

- Found in src/Subscription.sol [Line: 89](src/Subscription.sol#L89)

  ```solidity
          s_allowedTokenForOptionalChain = _allowedTokenForOptionalChain;
  ```

- Found in src/Subscription.sol [Line: 90](src/Subscription.sol#L90)

  ```solidity
          s_router = IRouterClient(_router);
  ```

- Found in src/Subscription.sol [Line: 91](src/Subscription.sol#L91)

  ```solidity
          s_sepoliaCheckBalanceAddress = _sepoliaCheckBalanceAddress;
  ```

- Found in src/Subscription.sol [Line: 92](src/Subscription.sol#L92)

  ```solidity
          s_sender = Sender(_sender);
  ```

</details>

## L-4: `public` functions not used internally could be marked `external`

Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

<details><summary>3 Found Instances</summary>

- Found in src/Receiver.sol [Line: 131](src/Receiver.sol#L131)

  ```solidity
      function withdrawToken(
  ```

- Found in src/Subscription.sol [Line: 161](src/Subscription.sol#L161)

  ```solidity
      function paySubscriptionFeeForOptionalChain(
  ```

- Found in src/Subscription.sol [Line: 203](src/Subscription.sol#L203)

  ```solidity
      function paySubscriptionFeeForPrimaryChain(
  ```

</details>

## L-5: Define and use `constant` variables instead of using literals

If the same constant literal value is used multiple times, create a constant state variable and reference it throughout the contract.

<details><summary>2 Found Instances</summary>

- Found in src/CheckBalance.sol [Line: 170](src/CheckBalance.sol#L170)

  ```solidity
              if (c >= 48 && c <= 57) {
  ```

- Found in src/CheckBalance.sol [Line: 171](src/CheckBalance.sol#L171)

  ```solidity
                  result = result * 10 + (c - 48);
  ```

</details>

## L-6: Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

<details><summary>7 Found Instances</summary>

- Found in src/CheckBalance.sol [Line: 64](src/CheckBalance.sol#L64)

  ```solidity
      event Response(
  ```

- Found in src/Receiver.sol [Line: 76](src/Receiver.sol#L76)

  ```solidity
      event TokensTransferred(
  ```

- Found in src/Receiver.sol [Line: 86](src/Receiver.sol#L86)

  ```solidity
      event NonceUpdated(address indexed subscriber, uint256 nonce);
  ```

- Found in src/Relayer.sol [Line: 38](src/Relayer.sol#L38)

  ```solidity
      event MessageSent(
  ```

- Found in src/Sender.sol [Line: 39](src/Sender.sol#L39)

  ```solidity
      event MessageSent(
  ```

- Found in src/Subscription.sol [Line: 55](src/Subscription.sol#L55)

  ```solidity
      event SubscriberToSubscriptionUpdated(
  ```

- Found in src/Subscription.sol [Line: 62](src/Subscription.sol#L62)

  ```solidity
      event Withdrawn(address token, uint256 amount);
  ```

</details>

## L-7: Modifiers invoked only once can be shoe-horned into the function

<details><summary>5 Found Instances</summary>

- Found in src/CheckBalance.sol [Line: 75](src/CheckBalance.sol#L75)

  ```solidity
      modifier initializedOnlyOnce() {
  ```

- Found in src/CheckBalance.sol [Line: 82](src/CheckBalance.sol#L82)

  ```solidity
      modifier hasInitialized() {
  ```

- Found in src/Receiver.sol [Line: 94](src/Receiver.sol#L94)

  ```solidity
      modifier validateReceiver(address _receiver) {
  ```

- Found in src/Sender.sol [Line: 52](src/Sender.sol#L52)

  ```solidity
      modifier initializedOnlyOnce() {
  ```

- Found in src/Sender.sol [Line: 59](src/Sender.sol#L59)

  ```solidity
      modifier hasInitialized() {
  ```

</details>

## L-8: Large literal values multiples of 10000 can be replaced with scientific notation

Use `e` notation, for example: `1e18`, instead of its full numeric value.

<details><summary>3 Found Instances</summary>

- Found in src/CheckBalance.sol [Line: 23](src/CheckBalance.sol#L23)

  ```solidity
      uint32 private constant GASLIMIT = 300000;
  ```

- Found in src/Relayer.sol [Line: 103](src/Relayer.sol#L103)

  ```solidity
                      gasLimit: 800_000, // Gas limit for the callback on the destination chain
  ```

- Found in src/Sender.sol [Line: 111](src/Sender.sol#L111)

  ```solidity
                      gasLimit: 3000_000, // Gas limit for the callback on the destination chain
  ```

</details>

## L-9: Internal functions called only once can be inlined

Instead of separating the logic into a separate function, consider inlining the logic into the calling function. This can reduce the number of function calls and improve readability.

<details><summary>2 Found Instances</summary>

- Found in src/Receiver.sol [Line: 148](src/Receiver.sol#L148)

  ```solidity
      function transferTokensPayLINK(
  ```

- Found in src/Relayer.sol [Line: 88](src/Relayer.sol#L88)

  ```solidity
      function sendMessage(
  ```

</details>

## L-10: Unused Custom Error

it is recommended that the definition be removed when custom error is unused

<details><summary>2 Found Instances</summary>

- Found in src/Receiver.sol [Line: 56](src/Receiver.sol#L56)

  ```solidity
      error AmoyReceiver__FailedToWithdrawEth(
  ```

- Found in src/Subscription.sol [Line: 48](src/Subscription.sol#L48)

  ```solidity
      error Subscription__AddConsumerFailed();
  ```

</details>

## L-11: Loop condition contains `state_variable.length` that could be cached outside.

Cache the lengths of storage arrays if they are used and not modified in for loops.

<details><summary>1 Found Instances</summary>

- Found in src/Subscription.sol [Line: 287](src/Subscription.sol#L287)

  ```solidity
          for (uint256 i = 0; i < s_subscriptionChainsSelector.length; i++) {
  ```

</details>

## L-12: Unused Imports

Redundant import statement. Consider removing it.

<details><summary>1 Found Instances</summary>

- Found in src/Subscription.sol [Line: 11](src/Subscription.sol#L11)

  ```solidity
  import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
  ```

</details>

## L-13: State variable could be declared constant

State variables that are not updated following deployment should be declared constant to save gas. Add the `constant` attribute to state variables that never change.

<details><summary>2 Found Instances</summary>

- Found in src/CheckBalance.sol [Line: 25](src/CheckBalance.sol#L25)

  ```solidity
      string private s_sourceForAllowedToken =
  ```

- Found in src/CheckBalance.sol [Line: 38](src/CheckBalance.sol#L38)

  ```solidity
      string private s_sourceForNativeToken =
  ```

</details>

## L-14: State variable changes but no event is emitted.

State variable changes in this function but no event is emitted.

<details><summary>3 Found Instances</summary>

- Found in src/CheckBalance.sol [Line: 105](src/CheckBalance.sol#L105)

  ```solidity
      function setSubscriptionAsOwner(
  ```

- Found in src/CheckBalance.sol [Line: 116](src/CheckBalance.sol#L116)

  ```solidity
      function sendRequest(
  ```

- Found in src/Sender.sol [Line: 83](src/Sender.sol#L83)

  ```solidity
      function setSubscriptionAsOwner(
  ```

</details>

## L-15: State variable could be declared immutable

State variables that are should be declared immutable to save gas. Add the `immutable` attribute to state variables that are only changed in the constructor

<details><summary>13 Found Instances</summary>

- Found in src/CheckBalance.sol [Line: 24](src/CheckBalance.sol#L24)

  ```solidity
      bytes32 private s_donID;
  ```

- Found in src/Receiver.sol [Line: 33](src/Receiver.sol#L33)

  ```solidity
      IRouterClient private s_router;
  ```

- Found in src/Receiver.sol [Line: 34](src/Receiver.sol#L34)

  ```solidity
      IERC20 private s_linkToken;
  ```

- Found in src/Relayer.sol [Line: 19](src/Relayer.sol#L19)

  ```solidity
      IRouterClient private s_router;
  ```

- Found in src/Relayer.sol [Line: 20](src/Relayer.sol#L20)

  ```solidity
      LinkTokenInterface private s_linkToken;
  ```

- Found in src/Sender.sol [Line: 18](src/Sender.sol#L18)

  ```solidity
      IRouterClient private s_router;
  ```

- Found in src/Sender.sol [Line: 19](src/Sender.sol#L19)

  ```solidity
      LinkTokenInterface private s_linkToken;
  ```

- Found in src/Subscription.sol [Line: 31](src/Subscription.sol#L31)

  ```solidity
      address private s_sepoliaCheckBalanceAddress;
  ```

- Found in src/Subscription.sol [Line: 32](src/Subscription.sol#L32)

  ```solidity
      uint64[] private s_subscriptionChainsSelector;
  ```

- Found in src/Subscription.sol [Line: 33](src/Subscription.sol#L33)

  ```solidity
      address private s_allowedToken;
  ```

- Found in src/Subscription.sol [Line: 34](src/Subscription.sol#L34)

  ```solidity
      address private s_allowedTokenForOptionalChain;
  ```

- Found in src/Subscription.sol [Line: 35](src/Subscription.sol#L35)

  ```solidity
      IRouterClient private s_router;
  ```

- Found in src/Subscription.sol [Line: 38](src/Subscription.sol#L38)

  ```solidity
      Sender private s_sender;
  ```

</details>