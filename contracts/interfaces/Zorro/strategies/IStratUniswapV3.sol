// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./IStrat.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/// @title IStratUniswapV3
/// @notice Interface for all strategies
interface IStratUniswapV3 is IStrat {
    /* Structs */

    struct ExecutionData {
        ISwapRouter router;
        address nfpManager;
        uint128 tokenId; // Only for withdrawals
        uint24 poolFee; // Only for deposits
        uint256 ratioToken0ToToken1; // Only for deposits. (Qty Token0 / Qty Token1) * 1e12. Not to be confused with exchange rates
        int24 tickLower;
        int24 tickUpper;
        bytes pathToken0;
        bytes pathToken1;
        uint256 exchRate0; // Expressed as (Qty Token OUT / Qty Token IN) * 1e12
        uint256 exchRate1;
    }

    /* Events */


    /* Functions */

    /// @notice Converts USD* to main asset and deposits it
    /// @param _amountUSD The amount of USD to deposit
    /// @param _maxSlippageFactor Max amount of slippage tolerated per UniswapV2 operation (9900 = 1%)
    /// @param _recipient Where the received tokens should be sent to
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.) (See child contract)
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) external;

    // TODO: Perhaps get rid of bytes memory data and just replace with a struct

    /// @notice Withdraws main asset, converts to USD*, and sends back to sender
    /// @param _amount The number of units of liquidity to withdraw
    /// @param _maxSlippageFactor Max amount of slippage tolerated per UniswapV2 operation (9900 = 1%)
    /// @param _recipient Where the withdrawn USD should be sent to
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.) (See child contract)
    function withdrawUSD(
        uint128 _liquidity,

        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) external;

    /// @notice Adds liquidity to an existing range, but using USD instead of the underlying tokens
    /// @param _tokenId The id of the erc721 token representing the liquidity position
    /// @param _amountUSDAdd The amount of USD to add to liquidity
    /// @param _maxMarketMovement Slippage tolerance (1% = 9900)
    /// @param _recipient Where to send collected fees to
    /// @param _data Encoding format: {router}{nfpmanager}{UniV3PathToken0ToStablecoin}{UniV3PathToken1ToStablecoin}{exchRateStablecoinPerToken0}{exchRateStablecoinPerToken1}
    /// @return liquidity The amount of liquidity added
    function increaseLiquidityUSD(
        uint256 _tokenId,
        uint256 _amountUSDAdd,
        uint256 _maxMarketMovement,
        address _recipient,
        bytes calldata _data
    ) external returns (uint128 liquidity);

    /// @notice Removes liquidity by a specified amount and returns funds as USD back to sender
    /// @param _tokenId The id of the erc721 token representing the liquidity position
    /// @param _liquidity the amount of liquidity added
    /// @param _maxMarketMovement Slippage tolerance (1% = 9900)
    /// @param _recipient Where to send collected fees to
    /// @param _data Encoding format: {router}{nfpmanager}{UniV3PathToken0ToStablecoin}{UniV3PathToken1ToStablecoin}{exchRateStablecoinPerToken0}{exchRateStablecoinPerToken1}
    /// @return amountUSD The amount of USD withdrawn from liquidity
    function decreaseLiquidityUSD(
        uint256 _tokenId,
        uint128 _liquidity,
        uint256 _maxMarketMovement,
        address _recipient,
        bytes calldata _data
    ) external returns (uint256 amountUSD);

    /// @notice Extracts the fees 
    /// @param _tokenId The id of the erc721 token representing the liquidity position
    /// @param _maxMarketMovement Slippage tolerance (1% = 9900)
    /// @param _recipient Where to send collected fees to
    /// @param _data Encoding format: {router}{nfpmanager}{UniV3PathToken0ToStablecoin}{UniV3PathToken1ToStablecoin}{exchRateStablecoinPerToken0}{exchRateStablecoinPerToken1}
    /// @return amountUSD The amount of USD withdrawn from liquidity
    function collectFeesUSD(
        uint256 _tokenId,
        uint256 _maxMarketMovement,
        address _recipient,
        bytes calldata _data
    ) external returns (uint256 amountUSD);
}
