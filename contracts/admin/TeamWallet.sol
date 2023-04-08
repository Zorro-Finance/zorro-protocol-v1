// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/finance/PaymentSplitterUpgradeable.sol";

/// @title TeamWallet
/// @notice PaymentSplitter wallet to allow for withdrawals proportional to team members' shares
contract TeamWallet is PaymentSplitterUpgradeable {}