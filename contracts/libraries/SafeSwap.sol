// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "./Utils.sol";

/// @title SafeSwapUni
/// @notice Library for safe swapping of ERC20 tokens for UniswapV3 and its clones
library SafeSwapUni {
    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* Functions */

    /// @notice Safely swaps from one token to another
    /// @dev Tries to use a Chainlink price feed oracle if one exists
    /// @param _uniRouter Uniswap V3 router
    /// @param _exactAmountIn The exact quantity of the origin token to swap
    /// @param _exchRate The exchange rate, expressed as (Qty OUT / Qty IN) * 1e12
    /// @param _maxMarketMovement Acceptable slippage (9900 = 1%)
    /// @param _path Path for V3 multihops https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps
    /// @param _recipient Where to send the swapped token to
    /// @return amountOut The quantity of tokens obtained from the swap
    function safeSwap(
        ISwapRouter _uniRouter,
        uint256 _exactAmountIn,
        uint256 _exchRate,
        uint256 _maxMarketMovement,
        bytes calldata _path,
        address _recipient
    ) internal returns (uint256 amountOut) {
        // Safety
        // TODO: Go through all require statements and ensure there's a ZORRO: Prefix for safety
        // Check to make sure the path has at least one uint24 fee + address token pair (3+20)
        require(_path.length >= 46, "ZORRO: notfullUniV3Path");

        // Decode token from path
        address _tokenIn = Utils.bytesToAddress(_path[:20]);

        // Safe approval
        IERC20Upgradeable(_tokenIn).safeIncreaseAllowance(
            address(_uniRouter),
            _exactAmountIn
        );

        // Calc min amount out
        uint256 _minAmountOut = _exactAmountIn * _exchRate * _maxMarketMovement / (1e12 * 10000);

        // Perform swap
        amountOut = _safeSwap(
            _uniRouter,
            _exactAmountIn,
            _minAmountOut,
            _path,
            _recipient,
            block.timestamp + 300
        );
    }

    /// @notice Internal function for safely swapping tokens (lower level than above func)
    /// @param _uniRouter Uniswap V3 router
    /// @param _exactAmountIn The exact quantity of the origin token to swap
    /// @param _minAmountOut The minimum quantity of destination token to be obtained
    /// @param _path Path for V3 multihops https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps
    /// @param _recipient Where to send the swapped token to
    /// @param _deadline How much time to allow for the transaction
    /// @return amountOut The quantity of tokens obtained from the swap
    function _safeSwap(
        ISwapRouter _uniRouter,
        uint256 _exactAmountIn,
        uint256 _minAmountOut,
        bytes calldata _path,
        address _recipient,
        uint256 _deadline
    ) private returns (uint256 amountOut) {
        // Requirements
        require(_exactAmountIn > 0, "amountIn zero");

        // Perform swap
        ISwapRouter.ExactInputParams memory _params =
            ISwapRouter.ExactInputParams({
                path: _path,
                recipient: _recipient,
                deadline: _deadline,
                amountIn: _exactAmountIn,
                amountOutMinimum: _minAmountOut
            });

        // Executes the swap.
        amountOut = swapRouter.exactInput(params);
    }
}
