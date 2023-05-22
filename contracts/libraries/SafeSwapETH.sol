// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./PriceFeed.sol";

import "../interfaces/Uniswap/IAMMRouter02.sol";

import "../interfaces/TraderJoe/IJoeRouter02.sol";

/// @title SafeSwapUniETH
/// @notice Library for safe swapping of ERC20 tokens to ETH for Uniswap/Pancakeswap style protocols
library SafeSwapUniETH {
    /* Libraries */

    using PriceFeed for AggregatorV3Interface;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* Functions */

    /// @notice Safely swaps from one token to exact ETH amount desired
    /// @dev Tries to use a Chainlink price feed oracle if one exists
    /// @param _uniRouter Uniswap V2 router
    /// @param _amountOutETH The exact quantity of ETH to be obtained
    /// @param _swapPath The array of tokens representing the swap path. Last element MUST be WETH.
    /// @param _priceFeedStart The Chainlink compatible price feed of the start token
    /// @param _priceFeedEnd The Chainlink compatible price feed of the end token
    /// @param _maxSlippageFactor The max slippage factor tolerated (9900 = 1%)
    /// @param _destination Where to send the swapped token to
    function safeSwapToETH(
        address _uniRouter,
        uint256 _amountOutETH,
        address[] memory _swapPath,
        AggregatorV3Interface _priceFeedStart,
        AggregatorV3Interface _priceFeedEnd,
        uint256 _maxSlippageFactor,
        address _destination
    ) internal {
        // Get price data
        (
            uint256[] memory _priceTokens,
            uint8[] memory _decimals
        ) = _preparePriceData(
                _swapPath[0],
                _swapPath[_swapPath.length - 1],
                _priceFeedStart,
                _priceFeedEnd
            );

        // Perform swap
        _safeSwapToETH(
            _uniRouter,
            _amountOutETH,
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
    /// @param _amountOutETH The exact quantity of ETH to obtain
    /// @param _priceTokens Array of prices of tokenIn in USD, times 1e12, then tokenOut
    /// @param _slippageFactor The maximum slippage factor tolerated for this swap
    /// @param _path The path to take for the swap
    /// @param _decimals The number of decimals for _amountIn, _amountOut
    /// @param _to The destination to send the swapped token to
    /// @param _deadline How much time to allow for the transaction
    function _safeSwapToETH(
        address _uniRouter,
        uint256 _amountOutETH,
        uint256[] memory _priceTokens,
        uint256 _slippageFactor,
        address[] memory _path,
        uint8[] memory _decimals,
        address _to,
        uint256 _deadline
    ) private {
        // Requirements
        require(_decimals.length == 2, "invalid dec");
        require(_path[0] != _path[_path.length - 1], "same token swap");
        require(_amountOutETH > 0, "amountOutETH zero");

        // Get max amount IN
        uint256 _amountInMax = _getAmountIn(
            _uniRouter,
            _amountOutETH,
            _path,
            _decimals,
            _priceTokens,
            _slippageFactor
        );

        // Safety
        uint256 _balIn = IERC20Upgradeable(_path[0]).balanceOf(address(this));
        require(_amountInMax <= _balIn, "amountIn exceeds balance");

        // Allowance
        IERC20Upgradeable(_path[0]).safeIncreaseAllowance(
            address(_uniRouter),
            _amountInMax
        );

        // Perform swap
        
        // Match router based on current chain Id
        // TODO: Make sure this is exhaustive (PCS, Polygon, etc.)
        if (block.chainid == 0xa86a) {
            // Avalanche
            IJoeRouter02(_uniRouter).swapTokensForExactAVAX(
                _amountOutETH,
                _amountInMax,
                _path,
                _to,
                _deadline
            );
        } else {
            // Generic router (Uniswap)
            IAMMRouter02(_uniRouter).swapTokensForExactETH(
                _amountOutETH,
                _amountInMax,
                _path,
                _to,
                _deadline
            );
        }
    }

    /// @notice Prepares token price data by attempting to use price feed oracle
    /// @dev Will assign price of zero in the absence of a feed. Subsequent funcs will need to recognize this and use the AMM price or some other source
    /// @param _startToken The origin token (to swap FROM)
    /// @param _endToken The destination token (to swap TO)
    /// @param _priceFeedStart The Chainlink compatible price feed of the start token
    /// @param _priceFeedEnd The Chainlink compatible price feed of the end token
    /// @return priceTokens Array of prices for each token in swap (length: 2). Zero if price feed could not be found
    /// @return decimals Array of ERC20 decimals for each token in swap (length: 2)
    function _preparePriceData(
        address _startToken,
        address _endToken,
        AggregatorV3Interface _priceFeedStart,
        AggregatorV3Interface _priceFeedEnd
    )
        private
        view
        returns (uint256[] memory priceTokens, uint8[] memory decimals)
    {
        // Get exchange rates of each token
        priceTokens = new uint256[](2);

        // If price feed exists, use latest round data. If not, assign zero
        if (address(_priceFeedStart) == address(0)) {
            priceTokens[0] = 0;
        } else {
            priceTokens[0] = _priceFeedStart.getExchangeRate();
        }
        if (address(_priceFeedEnd) == address(0)) {
            priceTokens[1] = 0;
        } else {
            priceTokens[1] = _priceFeedEnd.getExchangeRate();
        }

        // Get decimals
        decimals = new uint8[](2);
        decimals[0] = ERC20Upgradeable(_startToken).decimals();
        decimals[1] = ERC20Upgradeable(_endToken).decimals();
    }

    /// @notice Calculate max amount IN (account for slippage)
    /// @dev Tries to calculate based on price feed oracle if present, or via the AMM router
    /// @param _uniRouter Uniswap V2 router
    /// @param _amountOutETH The exact quantity of ETH to receive
    /// @param _path The path to take for the swap
    /// @param _decimals The number of decimals for _amountIn, _amountOut
    /// @param _priceTokens Array of prices of tokenIn in USD, times 1e12, then tokenOut
    /// @param _slippageFactor The maximum slippage factor tolerated for this swap
    /// @return amountOut Minimum amount of output token to expect
    function _getAmountIn(
        address _uniRouter,
        uint256 _amountOutETH,
        address[] memory _path,
        uint8[] memory _decimals,
        uint256[] memory _priceTokens,
        uint256 _slippageFactor
    ) private view returns (uint256 amountOut) {
        if (_priceTokens[0] == 0 || _priceTokens[1] == 0) {
            // If no exchange rates provided, use on-chain functions provided by router (not ideal)
            amountOut = _getAmountInWithoutExchangeRates(
                _uniRouter,
                _amountOutETH,
                _path,
                _slippageFactor
            );
        } else {
            amountOut = _getAmountInWithExchangeRates(
                _amountOutETH,
                _priceTokens[0],
                _priceTokens[1],
                _slippageFactor,
                _decimals
            );
        }
    }

    /// @notice Gets amounts out using provided exchange rates
    /// @param _amountOutETH The exact quantity of ETH to receive
    /// @param _priceTokenIn Price of input token in USD, quoted in the number of decimals of the price feed
    /// @param _priceTokenOut Price of output token in USD, quoted in the number of decimals of the price feed
    /// @param _slippageFactor Slippage tolerance (9900 = 1%)
    /// @param _decimals Array (length 2) of decimal of price feed for each token
    /// @return amountIn The quantity of tokens expected to be sent as input
    function _getAmountInWithExchangeRates(
        uint256 _amountOutETH,
        uint256 _priceTokenIn,
        uint256 _priceTokenOut,
        uint256 _slippageFactor,
        uint8[] memory _decimals
    ) internal pure returns (uint256 amountIn) {
        amountIn =
            (_amountOutETH *
                _priceTokenOut *
                10000 *
                10 ** _decimals[0]) /
            (_slippageFactor * _priceTokenIn * 10 ** _decimals[1]);
    }

    /// @notice Gets amounts in when exchange rates are not provided (uses router)
    /// @param _uniRouter The Uniswap V2 compatible router
    /// @param _amountOutETH The exact quantity of ETH to receive
    /// @param _path Array of tokens representing the swap path from input to output token
    /// @param _slippageFactor Slippage tolerance (9900 = 1%)
    /// @return amountIn The quantity of tokens expected to be sent as input
    function _getAmountInWithoutExchangeRates(
        address _uniRouter,
        uint256 _amountOutETH,
        address[] memory _path,
        uint256 _slippageFactor
    ) internal view returns (uint256 amountIn) {
        uint256[] memory amounts = IAMMRouter02(_uniRouter).getAmountsIn(
            _amountOutETH,
            _path
        );
        amountIn = (amounts[0] * 10000) / _slippageFactor;
    }
} 