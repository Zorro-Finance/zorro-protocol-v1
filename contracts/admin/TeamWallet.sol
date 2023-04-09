// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/finance/PaymentSplitterUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title TeamWallet
/// @notice PaymentSplitter wallet to allow for withdrawals proportional to team members' shares
contract TeamWallet is
    PaymentSplitterUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /* Initializer */

    /// @notice Initializes payment splitter and timelock
    /// @param _payees An array of addresses of payees
    /// @param _shares An array of corresponding shares for each payee
    /// @param _timelockOwner The designated owner of this contract (usually a timelock)
    function initialize(
        address[] memory _payees,
        uint256[] memory _shares,
        address _timelockOwner
    ) public initializer {
        // Call parent
        super.__PaymentSplitter_init(_payees, _shares);
        _transferOwnership(_timelockOwner);
    }

    /* Proxy implementations */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
