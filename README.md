# [`CCIPReader.sol`](./contracts//CCIPReader.sol)

When a CCIP-Read function is called, it bifurates: either it returns immediately or it continues after an `OffchainLookup` is processed.

To simplify this flow, inherit `CCIPReader` and use `ccipRead()` to call any CCIP-Read function.

```solidity
function ccipRead(
    address target, 
    bytes memory call, 
    bytes4 mySelector,
    bytes memory myCarry
) internal view returns (bytes memory);
```

After calling `ccipRead()`, the function either:
1. returns immediate ABI-encoded results from the callback
2. reverts `OffchainLookup` and then continues from the callback
3. reverts (due to call or callback failure)

Note: `ccipRead()` automatically handles recursive reverts.

```solidity
contract MyWrapper is CCIPReader {
    function doSomething() external view returns (...) {
        bytes memory v = ccipRead(
            /* target */
            /* calldata */,
            this.doSomethingCallback.selector, 
            abi.encode(1, "chonk")
        );
        // case #1: returned successfully from the call and the callback
        // case #2: reverted OffchainLookup
        // case #3: the call reverted or returned successful and the callback reverted
        // NOTE: always use this boilerplate after calling ccipRead()
        //       and place any extra logic inside of the callback
        assembly {
            return(add(v, 32), mload(v))
        }
    }

    // the return value of this function should match the return value of the caller
    function doSomethingCallback(
        bytes memory response, 
        bytes memory carry
    ) external view returns (...) {
        // case #1: response is immediate response from the call
        // case #2: response is response from OffchainLookup
        (uint256 one, string memory chonk) = abi.decode(carry, (uint256, string));
        // do any processing
    }
}
```

## [CCIPReadProtocol.sol](./contracts/CCIPReadProtocol.sol)

Solidity header which defines `OffchainLookup` and a helper function `CCIPReadProtocol.decode()` to decode revert calldata into an equivalent `OffchainLookupTuple` structure.

---

### Test

1. `npm i`
2. `npm test`
