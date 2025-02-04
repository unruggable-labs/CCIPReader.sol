// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CCIPReader} from "../contracts/CCIPReader.sol";

contract Wrapper is CCIPReader {
    function wrap(address target, bytes memory data, bytes memory carry)
        external
        view
        returns (bytes memory, bytes memory)
    {
        bytes memory v = ccipRead(target, data, this.wrapCallback.selector, carry);
        assembly {
            return(add(v, 32), mload(v))
        }
    }

    function wrapCallback(bytes memory ccip, bytes memory carry) external pure returns (bytes memory, bytes memory) {
        return (ccip, carry);
    }
}
