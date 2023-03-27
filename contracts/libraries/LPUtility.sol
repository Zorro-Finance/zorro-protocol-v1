// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/Uniswap/IAMMRouter02.sol";

/// @title LPUtility
/// @notice Library for adding/removing liquidity from LP pools
library LPUtility {
    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* Functions */

    /// @notice For adding liquidity to an LP pool
    /// @param _uniRouter Uniswap V2 router
    /// @param _token0 Address of the first token
    /// @param _token1 Address of the second token
    /// @param _token0Amt Quantity of Token0 to add
    /// @param _token1Amt Quantity of Token1 to add
    /// @param _maxSlippageFactor The max slippage allowed for swaps. 1000 = 0 %, 995 = 0.5%, etc.
    /// @param _recipient The recipient of the LP token
    function joinPool(
        IAMMRouter02 _uniRouter,
        address _token0,
        address _token1,
        uint256 _token0Amt,
        uint256 _token1Amt,
        uint256 _maxSlippageFactor,
        address _recipient
    ) internal {
        // Approve spending
        IERC20Upgradeable(_token0).safeIncreaseAllowance(address(_uniRouter), _token0Amt);
        IERC20Upgradeable(_token1).safeIncreaseAllowance(address(_uniRouter), _token1Amt);

        // Add liquidity
        _uniRouter.addLiquidity(
            _token0,
            _token1,
            _token0Amt,
            _token1Amt,
            (_token0Amt * _maxSlippageFactor) / 10000,
            (_token1Amt * _maxSlippageFactor) / 10000,
            _recipient,
            block.timestamp + 600
        );
    }

    /// @notice For removing liquidity from an LP pool
    /// @dev NOTE: Assumes LP token is already on contract
    /// @param _uniRouter Uniswap V2 router
    /// @param _amountLP The amount of LP tokens to remove
    /// @param _maxSlippageFactor The max slippage allowed for swaps. 10000 = 0 %, 9950 = 0.5%, etc.
    /// @param _recipient The recipient of the underlying tokens upon pool exit
    function exitPool(
        IAMMRouter02 _uniRouter,
        uint256 _amountLP,
        address _pool,
        address _token0,
        address _token1,
        uint256 _maxSlippageFactor,
        address _recipient
    ) internal {
        // Init
        uint256 _amount0Min;
        uint256 _amount1Min;

        {
            _amount0Min = _calcMinAmt(
                _amountLP,
                _token0,
                _pool,
                _maxSlippageFactor
            );
            _amount1Min = _calcMinAmt(
                _amountLP,
                _token1,
                _pool,
                _maxSlippageFactor
            );
        }

        // Approve
        IERC20Upgradeable(_pool).safeIncreaseAllowance(
                address(_uniRouter),
                _amountLP
            );

        // Remove liquidity
        _uniRouter.removeLiquidity(
            _token0,
            _token1,
            _amountLP,
            _amount0Min,
            _amount1Min,
            _recipient,
            block.timestamp + 300
        );
    }

    /// @notice Calculates minimum amount out for exiting LP pool
    /// @param _amountLP LP token qty
    /// @param _token Address of one of the tokens in the pair
    /// @param _pool Address of LP pair
    /// @param _slippageFactor Slippage (9900 = 1% etc.)
    function _calcMinAmt(
        uint256 _amountLP,
        address _token,
        address _pool,
        uint256 _slippageFactor
    ) private view returns (uint256) {
        // Get total supply and calculate min amounts desired based on slippage
        uint256 _totalSupply = IERC20Upgradeable(_pool).totalSupply();

        // Get balance of token in pool
        uint256 _balance = IERC20Upgradeable(_token).balanceOf(_pool);

        // Return min token amount out
        return
            (_amountLP * _balance * _slippageFactor) /
            (10000 * _totalSupply);
    }
}
