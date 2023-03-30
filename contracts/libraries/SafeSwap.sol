// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./PriceFeed.sol";

import "../interfaces/Uniswap/IAMMRouter02.sol";

/// @title SafeSwapUni
/// @notice Library for safe swapping of ERC20 tokens for Uniswap/Pancakeswap style protocols
library SafeSwapUni {
    /* Libraries */
    
    using PriceFeed for AggregatorV3Interface;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* Structs */

    struct SafeSwapParams {
        uint256 amountIn;
        uint256 priceToken0;
        uint256 priceToken1;
        address token0;
        address token1;
        uint256 maxMarketMovementAllowed;
        address[] path;
        address destination;
    }
    
    /* Functions */

    /// @notice Safely swaps from one token to another
    /// @dev Tries to use a Chainlink price feed oracle if one exists
    /// @param _uniRouter Uniswap V2 router
    /// @param _amountIn The quantity of the origin token to swap
    /// @param _startToken The origin token (to swap FROM)
    /// @param _endToken The destination token (to swap TO)
    /// @param _swapPath The array of tokens representing the swap path
    /// @param _priceFeedStart The Chainlink compatible price feed of the start token
    /// @param _priceFeedEnd The Chainlink compatible price feed of the end token
    /// @param _maxSlippageFactor The max slippage factor tolerated (9900 = 1%)
    /// @param _destination Where to send the swapped token to
    function safeSwap(
        IAMMRouter02 _uniRouter,
        uint256 _amountIn,
        address _startToken,
        address _endToken,
        address[] memory _swapPath,
        AggregatorV3Interface _priceFeedStart,
        AggregatorV3Interface _priceFeedEnd,
        uint256 _maxSlippageFactor,
        address _destination
    ) internal {
        // Get exchange rates of each token
        uint256[] memory _priceTokens = new uint256[](2);

        // If price feed exists, use latest round data. If not, assign zero
        if (address(_priceFeedStart) == address(0)) {
            _priceTokens[0] = 0;
        } else {
            _priceTokens[0] = _priceFeedStart.getExchangeRate();
        }
        if (address(_priceFeedEnd) == address(0)) {
            _priceTokens[1] = 0;
        } else {
            _priceTokens[1] = _priceFeedEnd.getExchangeRate();
        }

        // Get decimals
        uint8[] memory _decimals = new uint8[](2);
        _decimals[0] = ERC20Upgradeable(_startToken).decimals();
        _decimals[1] = ERC20Upgradeable(_endToken).decimals();

        // Safe transfer
        IERC20Upgradeable(_startToken).safeIncreaseAllowance(address(_uniRouter), _amountIn);

        // Perform swap
        _safeSwap(
            _uniRouter,
            _amountIn,
            _priceTokens,
            _maxSlippageFactor,
            _swapPath,
            _decimals,
            _destination,
            block.timestamp + 300
        );
    }

    /// @notice Internal function for safely swapping tokens (lower level than above func)
    /// @param _uniRouter Uniswap V2 router
    /// @param _amountIn The quantity of the origin token to swap
    /// @param _priceTokens Array of prices of tokenIn in USD, times 1e12, then tokenOut
    /// @param _slippageFactor The maximum slippage factor tolerated for this swap
    /// @param _path The path to take for the swap
    /// @param _decimals The number of decimals for _amountIn, _amountOut
    /// @param _to The destination to send the swapped token to
    /// @param _deadline How much time to allow for the transaction
    function _safeSwap(
        IAMMRouter02 _uniRouter,
        uint256 _amountIn,
        uint256[] memory _priceTokens,
        uint256 _slippageFactor,
        address[] memory _path,
        uint8[] memory _decimals,
        address _to,
        uint256 _deadline
    ) internal {
        // Requirements
        require(_decimals.length == 2, "invalid dec");
        require(_path[0] != _path[_path.length-1], "same token swap");
        require(_amountIn > 0, "amountIn zero");

        // Calculate min amount out (account for slippage)
        uint256 _amountOut;

        if (_priceTokens[0] == 0 || _priceTokens[1] == 0) {
            // If no exchange rates provided, use on-chain functions provided by router (not ideal)
            _amountOut = _getAmountOutWithoutExchangeRates(
                _uniRouter,
                _amountIn,
                _path,
                _slippageFactor,
                _decimals
            );
        } else {
            _amountOut = _getAmountOutWithExchangeRates(
                _amountIn,
                _priceTokens[0],
                _priceTokens[1],
                _slippageFactor,
                _decimals
            );
        }

        // Safety
        require(_amountOut > 0, "amountOut zero");

        // Perform swap
        _uniRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn,
            _amountOut,
            _path,
            _to,
            _deadline
        );
    }

    /// @notice Gets amounts out using provided exchange rates
    /// @param _amountIn The quantity of tokens as input to the swap
    /// @param _priceTokenIn Price of input token in USD, quoted in the number of decimals of the price feed
    /// @param _priceTokenOut Price of output token in USD, quoted in the number of decimals of the price feed
    /// @param _slippageFactor Slippage tolerance (9900 = 1%)
    /// @param _decimals Array (length 2) of decimal of price feed for each token
    /// @return amountOut The quantity of tokens expected to receive as output
    function _getAmountOutWithExchangeRates(
        uint256 _amountIn,
        uint256 _priceTokenIn,
        uint256 _priceTokenOut,
        uint256 _slippageFactor,
        uint8[] memory _decimals
    ) internal pure returns (uint256 amountOut) {
        amountOut =
            (_amountIn * _priceTokenIn * _slippageFactor * 10**_decimals[1]) /
            (10000 * _priceTokenOut * 10**_decimals[0]);
    }

    /// @notice Gets amounts out when exchange rates are not provided (uses router)
    /// @param _uniRouter The Uniswap V2 compatible router
    /// @param _amountIn The quantity of tokens as input to the swap
    /// @param _path Array of tokens representing the swap path from input to output token
    /// @param _slippageFactor Slippage tolerance (9900 = 1%)
    /// @param _decimals Array (length 2) of decimal of price feed for each token
    /// @return amountOut The quantity of tokens expected to receive as output
    function _getAmountOutWithoutExchangeRates(
        IAMMRouter02 _uniRouter,
        uint256 _amountIn,
        address[] memory _path,
        uint256 _slippageFactor,
        uint8[] memory _decimals
    ) internal view returns (uint256 amountOut) {
        uint256[] memory amounts = _uniRouter.getAmountsOut(_amountIn, _path);
        amountOut =
            (amounts[amounts.length - 1] * _slippageFactor * 10**_decimals[1]) /
            (10000 * (10**_decimals[0]));
    }
}
