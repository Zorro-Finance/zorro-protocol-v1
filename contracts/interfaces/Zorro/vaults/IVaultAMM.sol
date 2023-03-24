// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./IVault.sol";

/// @title IVaultAMM
/// @notice Interface for Standard AMM based vaults
interface IVaultAMM is IVault {
    /* Events */
    event DepositAsset(
        address indexed _pool,
        uint256 indexed _amount,
        uint256 indexed _sharesAdded
    );

    event DepositUSD(
        address indexed _pool,
        uint256 indexed _amountUSD,
        uint256 indexed _sharesAdded,
        uint256 _maxSlippageFactor
    );

    event WithdrawAsset(
        address indexed _pool,
        uint256 indexed _shares,
        uint256 indexed _amountAssetRemoved
    );

    event WithdrawUSD(
        address indexed _pool,
        uint256 indexed _amountUSD,
        uint256 indexed _sharesRemoved,
        uint256 _maxSlippageFactor
    );

    /* Functions */

    // Cash flow

    /// @notice Deposits main asset token into vault
    /// @param _amount The amount of asset to deposit
    function deposit(uint256 _amount) external;

    /// @notice Converts USD* to main asset and deposits it
    /// @param _amountUSD The amount of USD to deposit
    /// @param _maxSlippageFactor Max amount of slippage tolerated per AMM operation (9900 = 1%)
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor
    ) external;

    /// @notice Withdraws main asset and sends back to sender
    /// @param _shares The number of shares of the main asset to withdraw
    function withdraw(uint256 _shares) external;

    /// @notice Withdraws main asset, converts to USD*, and sends back to sender
    /// @param _shares The number of shares of the main asset to withdraw
    /// @param _maxSlippageFactor Max amount of slippage tolerated per AMM operation (9900 = 1%)
    function withdrawUSD(uint256 _shares, uint256 _maxSlippageFactor) external;

    // Accounting

    /// @notice The total amount of assets deposited and locked
    /// @return The amount in units of the main asset
    function assetLockedTotal() external view returns (uint256);

    // Key tokens, contracts, and config

    /// @notice The main asset (token) used in the underlying pool
    /// @return The address of the asset
    function asset() external view returns (address);

    /// @notice The default stablecoin (e.g. USDC, BUSD)
    /// @return The address of the stablecoin
    function stablecoin() external view returns (address);

    /// @notice The first token of the LP pair
    /// @return The address of the token
    function token0() external view returns (address);

    /// @notice The second token of the LP pair
    /// @return The address of the token
    function token1() external view returns (address);

    /// @notice The address of the farm contract (e.g. Masterchef)
    /// @return The address of the token
    function farmContract() external view returns (address);

    /// @notice The address of the farm token (e.g. CAKE, JOE)
    /// @return The address of the token
    function farmToken() external view returns (address);

    /// @notice The LP pool address
    /// @return The address of the pool
    function pool() external view returns (address);
}
