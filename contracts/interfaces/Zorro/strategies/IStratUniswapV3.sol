// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./IStrat.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/// @title IStratUniswapV3
/// @notice Interface for all strategies
interface IStratUniswapV3 is IStrat {
    /* Structs */

    struct ExecutionData {
        ISwapRouter router; // Router for UniV3 swaps
        address nfpManager; // Address of the NonfungiblePositionManager contract
        address token0;
        address token1;
        uint256 exchRate0; // Expressed as (Qty Token OUT / Qty Token IN) * 1e12. NOTE: This will be inverted depending on deposit/withdrawal
        uint256 exchRate1;
        uint256 maxSlippageFactor; // Slippage tolerance param (1% = 9900)
        address recipient; // Where to send resulting tokens to
        bytes pathToken0; // UniswapV3 Multihop path 
        bytes pathToken1;
    }

    /* Events */


    /* Functions */

    /// @notice Converts USD* to main asset and deposits it
    /// @dev Abstracts NonFungiblePositionManager.mint()
    /// @param _amountUSD The amount of USD to deposit
    /// @param _poolFee The fee tier for the underlying pool
    /// @param _ratioToken0ToToken1 Ratio of ((Qty Token0) / (Qty Token1)) * 1e12
    /// @param _ticks Array of lower, upper tick
    /// @param _data Data that encodes the pool specific params
    function depositUSD(
        uint256 _amountUSD,
        uint24 _poolFee,
        uint256 _ratioToken0ToToken1,
        int24[2] calldata _ticks,
        ExecutionData calldata _data
    ) external;

    /// @notice Withdraws main asset, converts to USD*, and sends back to sender
    /// @dev Abstracts NonfungiblePositionManager.decreaseLiquidity and .collectFees
    /// @param _tokenId The id of the erc721 token representing the liquidity position
    /// @param _amount0Min Min amount of Token0 to receive (should be calculated off chain)
    /// @param _amount1Min Min amount of Token1 to receive (should be calculated off chain)
    /// @param _liquidity The number of units of liquidity to withdraw
    /// @param _data Data that encodes the pool specific params
    function withdrawUSD(
        uint256 _tokenId,
        uint256 _amount0Min,
        uint256 _amount1Min,
        uint128 _liquidity,
        ExecutionData calldata _data
    ) external;

    /// @notice Adds liquidity to an existing range, but using USD instead of the underlying tokens
    /// @param _amountUSDAdd The amount of USD to add to liquidity
    /// @param _tokenId The id of the erc721 token representing the liquidity position
    /// @param _ratioToken0ToToken1 Ratio of ((Qty Token0) / (Qty Token1)) * 1e12
    /// @param _data Params specific to this operation
    /// @return liquidity The amount of liquidity added
    function increaseLiquidityUSD(
        uint256 _amountUSDAdd,
        uint256 _tokenId,
        uint256 _ratioToken0ToToken1,
        ExecutionData calldata _data
    ) external returns (uint128 liquidity);

    /// @notice Removes liquidity by a specified amount and returns funds as USD back to sender
    /// @param _tokenId The id of the erc721 token representing the liquidity position
    /// @param _amount0Min Min amount of Token0 to receive (should be calculated off chain)
    /// @param _amount1Min Min amount of Token1 to receive (should be calculated off chain)
    /// @param _liquidity the amount of liquidity added
    /// @param _data Params specific to this operation
    /// @return amountUSD The amount of USD withdrawn from liquidity
    function decreaseLiquidityUSD(
        uint256 _tokenId,
        uint256 _amount0Min,
        uint256 _amount1Min,
        uint128 _liquidity,
        ExecutionData calldata _data
    ) external returns (uint256 amountUSD);

    /// @notice Extracts the fees 
    /// @param _tokenId The id of the erc721 token representing the liquidity position
    /// @param _data Params specific to this operation
    /// @return amountUSD The amount of USD withdrawn from liquidity
    function collectFeesUSD(
        uint256 _tokenId,
        ExecutionData calldata _data
    ) external returns (uint256 amountUSD);
}
