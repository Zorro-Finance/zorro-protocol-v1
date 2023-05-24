// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./IVault.sol";

/// @title IVaultAMM
/// @notice Interface for Standard AMM based vaults
interface IVaultAMM is IVault {
    /* Events */
    event VaultAMMFailedEarn ();

    /* Structs */

    struct VaultAMMSwapPaths {
        address[] stablecoinToToken0;
        address[] stablecoinToToken1;
        address[] token0ToStablecoin;
        address[] token1ToStablecoin;
        address[] rewardsToToken0;
        address[] rewardsToToken1;
    }

    struct VaultAMMPriceFeeds {
        address token0;
        address token1;
        address eth;
        address stablecoin;
        address rewards;
    }

    struct VaultAMMInit {
        address asset;
        address token0;
        address token1;
        address farmContract;
        address rewardsToken;
        bool isFarmable;
        uint256 pid;
        address pool;
        VaultAMMSwapPaths swapPaths;
        VaultAMMPriceFeeds priceFeeds;
        VaultInit baseInit;
    }

    /* Functions */

    // Accounting

    /// @notice The total amount of assets deposited and locked
    /// @return The amount in units of the main asset
    function assetLockedTotal() external view returns (uint256);

    /// @notice When the last earn() was called
    /// @return The block timestamp
    function lastEarn() external view returns (uint256);

    // Key tokens, contracts, and config

    /// @notice The main asset (token) used in the underlying pool
    /// @return The address of the asset
    function asset() external view returns (address);

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
    function rewardsToken() external view returns (address);

    /// @notice The LP pool address
    /// @return The address of the pool
    function pool() external view returns (address);
}
