// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./IVault.sol";

/// @title IVaultUniswapV2
/// @notice Interface for Standard UniswapV2 based vaults
interface IVaultUniswapV2 is IVault {
    /* Structs */

    struct VaultUniswapV2SwapPaths {
        address[] stablecoinToToken0;
        address[] stablecoinToToken1;
        address[] token0ToStablecoin;
        address[] token1ToStablecoin;
    }

    struct VaultUniswapV2PriceFeeds {
        address token0;
        address token1;
        address eth;
        address stablecoin;
    }

    struct VaultUniswapV2Init {
        address asset;
        address token0;
        address token1;
        address pool;
        VaultUniswapV2SwapPaths swapPaths;
        VaultUniswapV2PriceFeeds priceFeeds;
        VaultInit baseInit;
    }

    /* Functions */

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

    /// @notice The LP pool address
    /// @return The address of the pool
    function pool() external view returns (address);
}
