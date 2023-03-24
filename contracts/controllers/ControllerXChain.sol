// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/Zorro/controllers/IControllerXChain.sol";

contract ControllerXChain is IControllerXChain, OwnableUpgradeable {
    /* Constructor */
    
    // TODO: Docstring
    function initialize() public initializer {
        // TODO
    }

    /* State */ 

    /* Setters */ 

    /* Deposits */ 

    // TODO: Docstrings

    // TODO: Fill in args

    function encodeDepositRequest(

    ) external view returns (bytes memory) {

    }

    function getDepositQuote(

    ) external view returns (uint256) {

    }

    function sendDepositRequest(

    ) external {

    }

    function receiveDepositRequest(

    ) external {

    }

    /* Withdrawals */

    function encodeWithdrawalRequest(

    ) external view returns (bytes memory) {

    }

    function getWithdrawalQuote(

    ) external view returns (uint256) {

    }

    function sendWithdrawalRequest(

    ) external {

    }

    function receiveWithdrawalRequest(

    ) external {

    }
}