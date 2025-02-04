// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OffchainLookup, OffchainLookupTuple, CCIPReadProtocol} from "./CCIPReadProtocol.sol";

/// A standardised Carry definition for use in the context of our `CCIPReader` architecture
struct Carry {
    address target;
    bytes4 callback;
    bytes carry;
    bytes4 myCallback;
    bytes myCarry;
}

contract CCIPReader {
    /**
     * @notice A function that wraps, handles, and consistently returns responses from calls to a function within a target contract that can return directly OR return in response to offchain data resolution (subject to the ERC-3668 specification).
     * @param target - the real contract where OUR execution will occur
     * @param call - the calldata that we want to execute against that target
     * @param mySelector - the 4 bytes selector of OUR callback exit point
     * @param myCarry - encoded bytes data that we want to pass through to our exit point
     */
    function ccipRead(address target, bytes memory call, bytes4 mySelector, bytes memory myCarry)
        internal
        view
        returns (bytes memory v)
    {
        /// We call the intended function that **could** revert with an `OffchainLookup`
        /// We destructure the response into an execution status bool and our return bytes
        bool ok;
        (ok, v) = target.staticcall(call);
        /// IF the function reverted with an `OffchainLookup`
        if (!ok && bytes4(v) == OffchainLookup.selector) {
            /// We decode the response error into a tuple
            /// tuples allow flexibility noting stack too deep constraints
            OffchainLookupTuple memory x = CCIPReadProtocol.decode(v);
            if (x.sender == target) {
                /// We then wrap the error data in an `OffchainLookup` sent/'owned' by this contract
                revert OffchainLookup(
                    address(this),
                    x.gateways,
                    x.request,
                    this.ccipReadCallback.selector,
                    abi.encode(Carry(target, x.selector, x.carry, mySelector, myCarry))
                );
            }
        }

        /// IF we have gotten here, the 'real' target does not revert with an `OffchainLookup` error
        if (ok) {
            /// The exit point of this architecture is  OUR callback in the 'real'
            /// We pass through the response to that callback
            (ok, v) = address(this).staticcall(abi.encodeWithSelector(mySelector, v, myCarry));
        }

        /// OR the call to the 'real' target reverts with a different error selector
        /// OR the call to OUR callback reverts with ANY error selector
        if (!ok) {
            assembly {
                revert(add(v, 32), mload(v))
            }
        }
    }

    function ccipReadCallback(bytes memory ccip, bytes memory carry) external view {
        Carry memory state = abi.decode(carry, (Carry));
        /// Since the callback can revert too (but has the same return structure)
        /// We can reuse the calling infrastructure to call the callback
        bytes memory v = ccipRead(
            state.target, abi.encodeWithSelector(state.callback, ccip, state.carry), state.myCallback, state.myCarry
        );
        assembly {
            return(add(v, 32), mload(v))
        }
    }
}
