# CCIPReader.sol

When a CCIP-Read function is called, it **bifurcates**: either (1) returns immediately or (2) continues after an `OffchainLookup` revert is processed.

To simplify this flow, inherit `CCIPReader` and use `ccipRead()` to call any CCIP-Read function.

```solidity
function ccipRead(
    address target, 
    bytes memory call, 
    bytes4 mySelector,
    bytes memory myCarry
) internal view returns (bytes memory);
```

After calling `ccipRead()`, either:
1. returns immediate ABI-encoded result from the callback
2. reverts `OffchainLookup` and then returns from the callback
3. reverts with an error (due to call or callback failure)

```solidity
contract MyWrapper is CCIPReader {
    function doSomething() external view returns (...) {
        bytes memory v = ccipRead(
            /* target */,
            /* calldata */,
            this.doSomethingCallback.selector, // our callback
            abi.encode(1, "chonk") // our call context
        );
        // case #1: returned successfully from the call and the callback
        // case #2: reverted OffchainLookup
        // case #3: the call reverted or returned successful and the callback reverted
        // NOTE: always use the following boilerplate after calling ccipRead()
        //       and place all post-call processing in the callback
        assembly {
            return(add(v, 32), mload(v))
        }
    }

    // NOTE: the return value of this function MUST be ABI-equivalent to the caller
    function doSomethingCallback(
        bytes memory response,
        bytes memory carry // our call context
    ) external view returns (...) {
        // case #1: response is from the call
        // case #2: response is from OffchainLookup
        (uint256 one, string memory chonk) = abi.decode(carry, (uint256, string));
        // post-call processing
    }
}
```

## CCIPReadProtocol.sol

Solidity header which defines `OffchainLookup` and a helper function `CCIPReadProtocol.decode()` that decodes revert calldata into an equivalent `OffchainLookupTuple` structure.

---

### Test

1. `npm i`
1. `npm test`
