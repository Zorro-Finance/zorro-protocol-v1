// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title Utils
/// @notice General utilities for working with Solidity
library Utils {
    /// @notice Decodes bytes to address
    /// @param _bys Bytes array (should be 20 bytes long)
    /// @return addr The resulting address
    function bytesToAddress(bytes memory _bys) internal pure returns (address addr) {
      assembly {
        addr := mload(add(_bys, 20))
      } 
    }
}