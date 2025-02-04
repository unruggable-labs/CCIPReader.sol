// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OffchainLookup} from "../contracts/CCIPReadProtocol.sol";

interface OffchainServer {
    function next(uint256 x) external view returns (uint256);
}

contract Offchain {
    string[] _gateways;

    constructor(string[] memory gateways) {
        _gateways = gateways;
    }

    function get(uint256 x) external view returns (uint256) {
        revert OffchainLookup(
            address(this), _gateways, abi.encodeCall(OffchainServer.next, (x)), this.getCallback.selector, ""
        );
    }

    function getCallback(bytes memory ccip, bytes calldata) external pure returns (uint256) {
        return abi.decode(ccip, (uint256));
    }

    function list(uint256 x) external view returns (uint256[] memory) {
        return _list(new uint256[](0), x);
    }

    function _list(uint256[] memory seq, uint256 x) internal view returns (uint256[] memory ret) {
        uint256 n = seq.length;
        ret = new uint256[](n + 1);
        for (uint256 i; i < n; i++) {
            ret[i] = seq[i];
        }
        ret[n] = x;
        if (x != 1) {
            revert OffchainLookup(
                address(this),
                _gateways,
                abi.encodeCall(OffchainServer.next, (x)),
                this.listCallback.selector,
                abi.encode(ret)
            );
        }
    }

    function listCallback(bytes calldata ccip, bytes calldata carry) external view returns (uint256[] memory) {
        return _list(abi.decode(carry, (uint256[])), abi.decode(ccip, (uint256)));
    }
}
