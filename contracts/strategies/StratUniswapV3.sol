// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./_StratBase.sol";

import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

/// @title StratUniswapV3
/// @notice Strategy contract for standard UniswapV3 based investment strategies
contract StratUniswapV3 is StratBase {
    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* Structs */

    struct ExecutionData {
        address router;
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

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _initVal A StratInit struct
    /// @param _timelockOwner The owner address (timelock)
    /// @param _gov The governor address for non timelock admin functions
    function initialize(
        StratInit memory _initVal,
        address _timelockOwner,
        address _gov
    ) public initializer {
        // Call parent constructor
        super.__StratBase_init(_initVal, _timelockOwner, _gov);
    }

    /* Functions */

    /// @inheritdoc	IStrat
    /// @param _data Encoding format: {router}{nfpmanager}{UniV3PathStablecoinToToken0}{UniV3PathStablecoinToToken1}{exchRateToken0PerStablecoin}{exchRateToken1PerStablecoin}
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) external {
        // Call internal deposit func
        _depositUSD(
            _amountUSD,
            _maxSlippageFactor,
            _recipient,
            _data
        );
    }

    /// @inheritdoc StratBase
    function _depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) internal override nonReentrant {
        // Unpack data
        (ExecutionData memory _execData) = abi.decode(
            _data,
            (ExecutionData)
        );

        // Safe transfer IN USD*
        IERC20Upgradeable(stablecoin).safeTransferFrom(
            _source,
            address(this),
            _amountUSD
        );

        // Collect fee on USD deposited
        _collectTradeFee(_amountUSD, entranceFeeFactor);

        {
            // Get balance of USD after fees
            uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
                address(this)
            );

            // Get relative amounts of each token
            uint256 _amount1USDToSwap = _balUSD / (_execData.ratioToken0ToToken1 + 1e12);
            uint256 _amount0USDToSwap = _balUSD - _amount1USDToSwap;

            // Swap USD* into token0, token1 (if applicable)
            if (_execData.token0 != stablecoin) {
                ISwapRouter(_execData.router).safeSwap(
                    _amount0USDToSwap,
                    _execData.exchRate0
                    _maxSlippageFactor,
                    _execData.pathToken0,
                    address(this)
                );
            }

            if (_execData.token1 != stablecoin) {
                ISwapRouter(_execData.router).safeSwap(
                    _amount1USDToSwap,
                    _execData.exchRate1
                    _maxSlippageFactor,
                    _execData.pathToken1,
                    address(this)
                );
            }
        }


        {
            // Get token balances
            uint256 _balToken0 = IERC20Upgradeable(_execData.token0).balanceOf(
                address(this)
            );
            uint256 _balToken1 = IERC20Upgradeable(_execData.token1).balanceOf(
                address(this)
            );

            // Add liquidity
            INonfungiblePositionManager.MintParams memory _params =
            INonfungiblePositionManager.MintParams({
                token0: _execData.token0,
                token1: _execData.token1,
                fee: _execData.poolFee,
                tickLower: _execData.tickLower,
                tickUpper: _execData.tickUpper,
                amount0Desired: _balToken0,
                amount1Desired: _balToken1,
                amount0Min: _balToken0 * _maxSlippageFactor,
                amount1Min: _balToken1 * _maxSlippageFactor,
                recipient: _recipient,
                deadline: block.timestamp
            });
            (
                uint256 _tokenId, 
                uint128 liquidity, 
                uint256 _amount0, 
                uint256 _amount1
            ) = INonfungiblePositionManager(_execData.nfpManager).mint(_params);

            // Refunds
            if (_amount0 < _balToken0) {
                IERC20Upgradeable(_execData.token0).safeTransfer(msg.sender, _balToken0 - _amount0);
            }
            if (_amount1 < _balToken1) {
                IERC20Upgradeable(_execData.token1).safeTransfer(msg.sender, _balToken1 - _amount1);
            }
            // TODO: Test refunds
        }


        // Emit log
        emit DepositUSD(_amountUSD);
    }

    // TODO: Withdrawal flow

    /// @inheritdoc	IStrat
    /// @param _data Encoding format: {router}{nfpmanager}{UniV3PathToken0ToStablecoin}{UniV3PathToken1ToStablecoin}{exchRateStablecoinPerToken0}{exchRateStablecoinPerToken1}
    function withdrawUSD(
        uint128 _liquidity,
        uint256 _tokenId,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) external {
        // Call internal withdrawal function
        // Note: 0 for reimbursement because this is not a permit transaction
        _withdrawUSD(
            _liquidity,
            _tokenId,
            _maxSlippageFactor,
            _recipient,
            _data
        );
    }

    /// @inheritdoc StratBase
    /// @param _liquidity The amount of liquidity to withdraw
    function _withdrawUSD(
        uint128 _liquidity,
        uint256 _tokenId,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) internal override nonReentrant {
        // Unpack data
        (ExecutionData memory _execData) = abi.decode(
            _data,
            (ExecutionData)
        );

        // Safe Transfer LP tokens IN
        IERC20Upgradeable(_execData.pool).safeTransferFrom(
            _source,
            address(this),
            _lpShares
        );

        // Remove liquidity
        IUniswapV2Router02(_execData.router).exitPool(
            _lpShares,
            _execData.pool,
            _execData.token0,
            _execData.token1,
            _maxSlippageFactor,
            address(this)
        );

        {

            // Calc balance of Tokens 0,1
            uint256 _balToken0 = IERC20Upgradeable(_execData.token0).balanceOf(
                address(this)
            );
            uint256 _balToken1 = IERC20Upgradeable(_execData.token1).balanceOf(
                address(this)
            );

            // Swap Tokens 0,1 to USD*
            if (_execData.token0 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balToken0,
                    _execData.swapPathToken0ToStablecoin,
                    priceFeeds[_execData.token0],
                    priceFeeds[stablecoin],
                    _maxSlippageFactor,
                    address(this)
                );
            }
            if (_execData.token1 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balToken1,
                    _execData.swapPathToken1ToStablecoin,
                    priceFeeds[_execData.token1],
                    priceFeeds[stablecoin],
                    _maxSlippageFactor,
                    address(this)
                );
            }
        }

        // Get balances of USD*
        uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );

        // Collect fee on USD deposited
        _collectTradeFee(_balUSD, withdrawFeeFactor);

        // Update remaining USD for withdrawal
        _balUSD = IERC20Upgradeable(stablecoin).balanceOf(address(this));

        // Transfer USD*
        IERC20Upgradeable(stablecoin).safeTransfer(_recipient, _balUSD);

        // Emit log
        emit WithdrawUSD(_balUSD);
    }

    /* Proxy implementations */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
