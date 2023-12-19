// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./_StratBase.sol";

import "../interfaces/Uniswap/V3/INonfungiblePositionManager.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "../interfaces/Zorro/strategies/IStratUniswapV3.sol";

/// @title StratUniswapV3
/// @notice Strategy contract for standard UniswapV3 based investment strategies
contract StratUniswapV3 is StratBase, IStratUniswapV3 {
    /* Libraries */

    using SafeERC20 for IERC20;
    using SafeSwapUni for ISwapRouter;

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _timelockOwner The owner address (timelock)
    /// @param _gov The governor address for non timelock admin functions
    /// @param _initVal A StratInit struct
    function initialize(
        address _timelockOwner,
        address _gov,
        StratInit calldata _initVal
    ) public initializer {
        // Call parent constructor
        super.__StratBase_init(_timelockOwner, _gov, _initVal);
    }

    /* Functions */

    /// @inheritdoc	IStratUniswapV3
    function depositUSD(
        uint256 _amountUSD,
        uint24 _poolFee,
        uint256 _ratioToken0ToToken1,
        int24[2] calldata _ticks,
        ExecutionData calldata _data
    ) external {
        // Safe transfer IN USD*
        IERC20(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            _amountUSD
        );

        // Collect fee on USD deposited
        _collectTradeFee(_amountUSD, defaultFeeFactor);

        // Swap USD to Token0, Token1
        (uint256 _amount0Avail, uint256 _amount1Avail) = _swapStablecoinToTokens(_ratioToken0ToToken1, _data);

        {

            // Add liquidity
            INonfungiblePositionManager.MintParams memory _params =
            INonfungiblePositionManager.MintParams({
                token0: _data.token0,
                token1: _data.token1,
                fee: _poolFee,
                tickLower: _ticks[0],
                tickUpper: _ticks[1],
                amount0Desired: _amount0Avail,
                amount1Desired: _amount1Avail,
                amount0Min: _amount0Avail * _data.maxSlippageFactor,
                amount1Min: _amount1Avail * _data.maxSlippageFactor,
                recipient: _data.recipient,
                deadline: block.timestamp
            });
            (
                ,, 
                uint256 _amount0, 
                uint256 _amount1
            ) = INonfungiblePositionManager(_data.nfpManager).mint(_params);

            // Refunds
            _refundTokens(
                _data.recipient, 
                IERC20(_params.token0), 
                IERC20(_params.token1), 
                _amount0, _amount1, 
                _amount0Avail, 
                _amount1Avail
            );
        }
    }

    /// @inheritdoc	IStratUniswapV3
    function increaseLiquidityUSD(
        uint256 _amountUSD,
        uint256 _tokenId,
        uint256 _ratioToken0ToToken1,
        ExecutionData calldata _data
    ) external returns (uint128 liquidity) {
        // Safe transfer IN USD*
        IERC20(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            _amountUSD
        );

        // Collect fee on USD deposited
        _collectTradeFee(_amountUSD, defaultFeeFactor);

        // Swap USD to Token0, Token1
        (uint256 _amount0Avail, uint256 _amount1Avail) = _swapStablecoinToTokens(_ratioToken0ToToken1, _data);

        {
            // Add liquidity
            INonfungiblePositionManager.IncreaseLiquidityParams memory _params =
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: _tokenId,
                amount0Desired: _amount0Avail,
                amount1Desired: _amount1Avail,
                amount0Min: _amount0Avail * _data.maxSlippageFactor,
                amount1Min: _amount1Avail * _data.maxSlippageFactor,
                deadline: block.timestamp
            });
            (
                uint128 _liquidity, 
                uint256 _amount0, 
                uint256 _amount1
            ) = INonfungiblePositionManager(_data.nfpManager).increaseLiquidity(_params);
            liquidity = _liquidity;

            // Refunds
            _refundTokens(
                _data.recipient, 
                IERC20(_data.token0),
                IERC20(_data.token1),
                _amount0, _amount1, 
                _amount0Avail, 
                _amount1Avail
            );
        }
    }

    /// @inheritdoc	IStratUniswapV3
    function withdrawUSD(
        uint256 _tokenId,
        uint256 _amount0Min,
        uint256 _amount1Min,
        uint128 _liquidity,
        ExecutionData calldata _data
    ) external {
        // Safe Transfer liquidity tokens IN
        INonfungiblePositionManager(_data.nfpManager).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        // Decrease liquidity
        (uint256 _amount0liq, uint256 _amount1liq) = _decreaseLiquidity(_tokenId, _amount0Min, _amount1Min, _liquidity, _data);

        // Collect fees
        (uint256 _amount0Fees, uint256 _amount1Fees) = _collectFees(
            _data.nfpManager,
            _tokenId
        );

        // Swap to USD
        uint256 _amountUSD = _swapTokensToStablecoin(
            _amount0liq + _amount0Fees, 
            _amount1liq + _amount1Fees,
            _data 
        );

        // Collect protocol fees and send funds to user
        _collectFeeAndXferWithdrawal(_amountUSD, _data.recipient);
    }

    /// @inheritdoc	IStratUniswapV3
    function decreaseLiquidityUSD(
        uint256 _tokenId,
        uint256 _amount0Min,
        uint256 _amount1Min,
        uint128 _liquidity,
        ExecutionData calldata _data
    ) external returns (uint256 amountUSD) {
        // Transfer liquidity IN
        INonfungiblePositionManager(_data.nfpManager).safeTransferFrom(msg.sender, address(this), _tokenId);

        // Decrease liquidity
        (uint256 _amount0, uint256 _amount1) = _decreaseLiquidity(_tokenId, _amount0Min, _amount1Min, _liquidity, _data);

        // Swap to USD
        amountUSD = _swapTokensToStablecoin(_amount0, _amount1, _data);

        // Collect protocol fees and send funds to user
        amountUSD = _collectFeeAndXferWithdrawal(amountUSD, _data.recipient);
    }

    /// @notice Internal function for decreasing liquidity in UniV3. (Does not swap to USD)
    /// @param _tokenId The token ID reprsenting the liquidity position
    /// @param _amount0Min Min amount of Token0 expected to receive
    /// @param _amount1Min Min amount of Token1 expected to receive
    /// @param _liquidity The amount of liquidity to decrease by
    /// @param _data ExecutionData object
    /// @return amount0 The amount of fees collected in Token0
    /// @return amount1 The amount of fees collected in Token1
    function _decreaseLiquidity(
        uint256 _tokenId,
        uint256 _amount0Min,
        uint256 _amount1Min,
        uint128 _liquidity,
        ExecutionData calldata _data
    ) internal returns (uint256 amount0, uint256 amount1) {
        // Decrease liquidity
        INonfungiblePositionManager.DecreaseLiquidityParams memory _params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: _tokenId,
                liquidity: _liquidity,
                amount0Min: _amount0Min,
                amount1Min: _amount1Min,
                deadline: block.timestamp
            });

        return INonfungiblePositionManager(_data.nfpManager).decreaseLiquidity(_params);
    }

    /// @inheritdoc	IStratUniswapV3
    function collectFeesUSD(
        uint256 _tokenId,
        ExecutionData calldata _data
    ) external returns (uint256 amountUSD) {
        // Transfer liquidity IN
        INonfungiblePositionManager(_data.nfpManager).safeTransferFrom(msg.sender, address(this), _tokenId);

        // Collect earned fees
        (uint256 _amount0, uint256 _amount1) = _collectFees(
            _data.nfpManager,
            _tokenId
        );

        // Swap to USD
        amountUSD = _swapTokensToStablecoin(_amount0, _amount1, _data);

        // Collect protocol fees and send funds to user
        amountUSD = _collectFeeAndXferWithdrawal(amountUSD, _data.recipient);
    }

    /// @notice Internal function for collecting UniV3 fees earned (does not swap to USD)
    /// @dev Assumes NFT liquidity already transferred in
    /// @param _nfpManager Address of the NonfungiblePositionManager contract
    /// @param _tokenId Token ID of the liquidity position
    /// @return amount0 The amount of fees collected in Token0
    /// @return amount1 The amount of fees collected in Token1
    function _collectFees(
        address _nfpManager,
        uint256 _tokenId
    ) internal returns (uint256 amount0, uint256 amount1) {
        // Collect fees
        INonfungiblePositionManager.CollectParams memory _params =
            INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        return INonfungiblePositionManager(_nfpManager).collect(_params);
    }

    function _collectFeeAndXferWithdrawal(
        uint256 _amountUSD, 
        address _recipient
    ) internal returns (uint256 netAmountUSD) {
        // Protocol Collect fee on USD deposited
        _collectTradeFee(_amountUSD, defaultFeeFactor);

        // Update remaining USD for withdrawal
        netAmountUSD = IERC20(stablecoin).balanceOf(address(this));

        // Transfer USD*
        IERC20(stablecoin).safeTransfer(_recipient, netAmountUSD);
    }

    /* Utils */

    /// @notice Swaps USD to Token0 and Token1
    /// @param _ratioToken0ToToken1 Ratio of ((Qty Token0) / (Qty Token1)) * 1e12
    /// @param _data The execution data (contains swap parameters)
    /// @return amount0Avail The amount of Token0 obtained. If no swap was needed, shows balance of Token0 instead
    /// @return amount1Avail Same except for Token1
    function _swapStablecoinToTokens(
        uint256 _ratioToken0ToToken1,
        ExecutionData calldata _data
    ) internal returns (uint256 amount0Avail, uint256 amount1Avail) {
        // Get balance of USD after fees
        uint256 _balUSD = IERC20(stablecoin).balanceOf(
            address(this)
        );

        // Get relative amounts of each token
        uint256 _amount1USDToSwap = _balUSD / (_ratioToken0ToToken1 + 1e12);
        uint256 _amount0USDToSwap = _balUSD - _amount1USDToSwap;

        // Swap USD* into token0, token1 (if applicable)
        if (_data.token0 != stablecoin) {
            amount0Avail = _data.router.safeSwap(
                stablecoin,
                _amount0USDToSwap,
                _data.exchRate0,
                _data.maxSlippageFactor,
                _data.pathToken0,
                address(this)
            );
        }

        if (_data.token1 != stablecoin) {
            amount1Avail = _data.router.safeSwap(
                stablecoin,
                _amount1USDToSwap,
                _data.exchRate1,
                _data.maxSlippageFactor,
                _data.pathToken1,
                address(this)
            );
        }

        // If swaps were not performed (e.g. if token was the stablecoin), calculate the balance
        if (amount0Avail == 0) {
            amount0Avail = IERC20(_data.token0).balanceOf(address(this));
        }
        if (amount1Avail == 0) {
            amount1Avail = IERC20(_data.token1).balanceOf(address(this));
        }
    }

    /// @notice Swaps Token0 and Token1 into USD (if applicable)
    /// @param _amount0 Amount of Token0 to swap
    /// @param _amount1 Amount of Token1 to swap
    /// @param _data The execution data (contains swap parameters)
    /// @return amountUSD The amount of USD obtained
    function _swapTokensToStablecoin(
        uint256 _amount0,
        uint256 _amount1,
        ExecutionData calldata _data
    ) internal returns (uint256 amountUSD) {
        // Swap token0, token1 to USD (if applicable)
        if (_data.token0 != stablecoin) {
            amountUSD += _data.router.safeSwap(
                _data.token0,
                _amount0,
                _data.exchRate0,
                _data.maxSlippageFactor,
                _data.pathToken0,
                address(this)
            );
        }

        if (_data.token1 != stablecoin) {
            amountUSD += _data.router.safeSwap(
                _data.token1,
                _amount1,
                _data.exchRate1,
                _data.maxSlippageFactor,
                _data.pathToken1,
                address(this)
            );
        }
    }

    /// @notice Refunds any unspent tokens back to the specified user
    /// @param _recipient Where to send unspent tokens to
    /// @param _token0 Address of Token0
    /// @param _token1 Address of Token1
    /// @param _amount0 Amount of Token0 used
    /// @param _amount1 Amount of Token1 used
    /// @param _amount0Avail Amount of Token0 available for the operation (e.g. adding liquidity)
    /// @param _amount1Avail Amount of Token1 available for the operation (e.g. adding liquidity)
    function _refundTokens(
        address _recipient, 
        IERC20 _token0, 
        IERC20 _token1, 
        uint256 _amount0, 
        uint256 _amount1, 
        uint256 _amount0Avail, 
        uint256 _amount1Avail
    ) internal {
        if (_amount0 < _amount0Avail) {
            _token0.safeTransfer(_recipient, _amount0Avail - _amount0);
        }

        if (_amount1 < _amount1Avail) {
            _token1.safeTransfer(_recipient, _amount1Avail - _amount1);
        }
    }

    /* Proxy implementations */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}