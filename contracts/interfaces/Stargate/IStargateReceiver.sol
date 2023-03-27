// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

interface IStargateReceiver {
    /// @notice Function for composable logic on the destination chain
    /// @dev See https://stargateprotocol.gitbook.io/stargate/interfaces/evm-solidity-interfaces/istargatereceiver.sol
    /// @param _chainId Origin LayerZero chain ID that sent the tokens
    /// @param _srcAddress The remote bridge address
    /// @param _nonce Nonce to track transaction
    /// @param _token The token contract on the local chain
    /// @param amountLD The qty of local _token contract tokens
    /// @param payload Payload sent from source chain to be executed here
    function sgReceive(
        uint16 _chainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        address _token,
        uint256 amountLD,
        bytes memory payload
    ) external;
}
