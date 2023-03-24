// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IControllerXChain {
    /* Events */ 

    /* Deposits */ 

    // TODO: Docstrings

    // TODO: Fill in args

    function encodeDepositRequest(

    ) external view returns (bytes memory);

    function getDepositQuote(

    ) external view returns (uint256);

    function sendDepositRequest(

    ) external;

    function receiveDepositRequest(

    ) external;

    /* Withdrawals */

    function encodeWithdrawalRequest(

    ) external view returns (bytes memory);

    function getWithdrawalQuote(

    ) external view returns (uint256);

    function sendWithdrawalRequest(

    ) external;

    function receiveWithdrawalRequest(

    ) external;
}