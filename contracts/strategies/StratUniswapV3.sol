// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./_StratBase.sol";

import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import "../interfaces/Zorro/strategies/IStratUniswapV3.sol";

/// @title StratUniswapV3
/// @notice Strategy contract for standard UniswapV3 based investment strategies
contract StratUniswapV3 is StratBase, IStratUniswapV3 {
    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;

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
    /// @dev Abstracts NonFungiblePositionManager.mint()
    /// @param _data Encoding format: {router}{nfpmanager}{UniV3PathStablecoinToToken0}{UniV3PathStablecoinToToken1}{exchRateToken0PerStablecoin}{exchRateToken1PerStablecoin}
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) external {
        // Unpack data
        (ExecutionData memory _execData) = abi.decode(
            _data,
            (ExecutionData)
        );

        // Safe transfer IN USD*
        IERC20Upgradeable(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            _amountUSD
        );

        // Collect fee on USD deposited
        _collectTradeFee(_amountUSD, defaultFeeFactor);

        // Swap USD to Token0, Token1
        (uint256 _amount0Avail, uint256 _amount1Avail) = _swapStablecoinToTokens(_execData, _maxSlippageFactor);

        {

            // Add liquidity
            INonfungiblePositionManager.MintParams memory _params =
            INonfungiblePositionManager.MintParams({
                token0: Utils.bytesToAddress(_execData.pathToken0[:20]),
                token1: Utils.bytesToAddress(_execData.pathToken1[:20]),
                fee: _execData.poolFee,
                tickLower: _execData.tickLower,
                tickUpper: _execData.tickUpper,
                amount0Desired: _amount0Avail,
                amount1Desired: _amount1Avail,
                amount0Min: _amount0Avail * _maxSlippageFactor,
                amount1Min: _amount1Avail * _maxSlippageFactor,
                recipient: _recipient,
                deadline: block.timestamp
            });
            (
                uint256 _tokenId, 
                uint128 _liquidity, 
                uint256 _amount0, 
                uint256 _amount1
            ) = INonfungiblePositionManager(_execData.nfpManager).mint(_params);

            // Refunds
            _refundTokens(
                _recipient, 
                _params.token0, 
                _params.token1, 
                _amount0, _amount1, 
                _amount0Avail, 
                _amount1Avail
            );
        }
    }

    /// @inheritdoc	IStratUniswapV3
    function increaseLiquidityUSD(
        uint256 _tokenId,
        uint256 _amountUSD,
        uint256 _maxSlippageFactor
    ) returns (uint128 liquidity) external {
        // Safe transfer IN USD*
        IERC20Upgradeable(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            _amountUSD
        );

        // Collect fee on USD deposited
        _collectTradeFee(_amountUSD, defaultFeeFactor);

        // Swap USD to Token0, Token1
        (uint256 _amount0Avail, uint256 _amount1Avail) = _swapStablecoinToTokens(_execData, _maxSlippageFactor);

        {
            // Add liquidity
            INonfungiblePositionManager.IncreaseLiquidityParams memory _params =
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: _tokenId,
                amount0Desired: _amount0Avail,
                amount1Desired: _amount1Avail,
                amount0Min: _amount0Avail * _maxSlippageFactor,
                amount1Min: _amount1Avail * _maxSlippageFactor,
                deadline: block.timestamp
            });
            (
                uint128 _liquidity, 
                uint256 _amount0, 
                uint256 _amount1
            ) = INonfungiblePositionManager(_execData.nfpManager).increaseLiquidity(_params);

            // Refunds
            _refundTokens(
                _recipient, 
                _params.token0, 
                _params.token1, 
                _amount0, _amount1, 
                _amount0Avail, 
                _amount1Avail
            );
        }
    }

    /// @inheritdoc	IStrat
    /// @dev Abstracts NonfungiblePositionManager.decreaseLiquidity and .collectFees
    /// @param _data Encoding format: {router}{nfpmanager}{UniV3PathToken0ToStablecoin}{UniV3PathToken1ToStablecoin}{exchRateStablecoinPerToken0}{exchRateStablecoinPerToken1}
    function withdrawUSD(
        uint128 _liquidity,
        uint256 _tokenId,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) external {
        // Unpack data
        (ExecutionData memory _execData) = abi.decode(
            _data,
            (ExecutionData)
        );

        // Safe Transfer liquidity tokens IN
        INonfungiblePositionManager(_execData.nfpManager).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
        );

        // Decrease liquidity
        (uint256 _amount0liq, uint256 _amount1liq) = _decreaseLiquidity(_tokenId, _liquidity, _maxSlippageFactor, _execData);

        // Collect fees
        (uint256 _amount0Fees, uint256 _amount1Fees) = _collectFees(_tokenId, _execData);

        // Swap to USD
        uint256 _amountUSD = _swapTokensToStablecoin(
            _execData, 
            _amount0liq + _amount0Fees, 
            _amount1liq + _amount1Fees, 
            _maxSlippageFactor
        );

        // Protocol Collect fee on USD deposited
        _collectTradeFee(_amountUSD, defaultFeeFactor);

        // Update remaining USD for withdrawal
        _amountUSD = IERC20Upgradeable(stablecoin).balanceOf(address(this));

        // Transfer USD*
        IERC20Upgradeable(stablecoin).safeTransfer(_recipient, _amountUSD);
    }

    /// @inheritdoc	IStratUniswapV3
    function decreaseLiquidityUSD(
        uint256 _tokenId,
        uint128 _liquidity,
        uint256 _maxSlippageFactor,
        bytes memory _data,
        address _recipient
    ) returns (uint256 amountUSD) external {
        // TODO: This pattern repeats a lot. Abstract it out
        // Unpack data
        (ExecutionData memory _execData) = abi.decode(
            _data,
            (ExecutionData)
        );

        // Transfer liquidity IN
        INonfungiblePositionManager(_execData.nfpManager).safeTransferFrom(msg.sender, address(this), _tokenId);

        // Decrease liquidity
        (uint256 _amount0, uint256 _amount1) = _decreaseLiquidity(_tokenId, _liquidity, _maxSlippageFactor, _execData);

        // Swap to USD
        amountUSD = _swapTokensToStablecoin(_execData, _amount0, _amount1, _maxSlippageFactor);

        // TODO: This pattern also repeats a lot. Abstract it out.
        // Protocol Collect fee on USD deposited
        _collectTradeFee(amountUSD, defaultFeeFactor);

        // Update remaining USD for withdrawal
        amountUSD = IERC20Upgradeable(stablecoin).balanceOf(address(this));

        // Transfer USD*
        IERC20Upgradeable(stablecoin).safeTransfer(_recipient, amountUSD);
    }

    /// @notice Internal function for decreasing liquidity in UniV3. (Does not swap to USD)
    /// @param _tokenId The token ID reprsenting the liquidity position
    /// @param _liquidity The amount of liquidity to decrease by
    /// @param _maxSlippageFactor Slippage (1% = 9900)
    /// @param _execData ExecutionData object
    /// @return amount0 The amount of fees collected in Token0
    /// @return amount1 The amount of fees collected in Token1
    function _decreaseLiquidity(
        uint256 _tokenId,
        uint128 _liquidity,
        uint256 _maxSlippageFactor,
        ExecutionData memory _execData
    ) internal returns (uint256 amount0, uint256 amount1) {
        // Decrease liquidity
        INonfungiblePositionManager.DecreaseLiquidityParams memory _params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: _tokenId,
                liquidity: _liquidity,
                amount0Min: 0, // TODO Calculate amounts min
                amount1Min: 0,
                deadline: block.timestamp
            });

        return INonfungiblePositionManager(_execData.nfpManager).decreaseLiquidity(_params);
    }

    /// @inheritdoc	IStratUniswapV3
    function collectFeesUSD(
        uint256 _tokenId,
        uint256 _maxSlippageFactor,
        bytes memory _data
    ) returns (uint256 amountUSD) external {
        // Unpack data
        (ExecutionData memory _execData) = abi.decode(
            _data,
            (ExecutionData)
        );

        // Transfer liquidity IN
        INonfungiblePositionManager(_execData.nfpManager).safeTransferFrom(msg.sender, address(this), _tokenId);

        // Collect earned fees
        (uint256 _amount0, uint256 _amount1) = _collectFees(_tokenId, _execData);

        // Swap to USD
        amountUSD = _swapTokensToStablecoin(_execData, _amount0, _amount1, _maxSlippageFactor);

        // Protocol Collect fee on USD deposited
        _collectTradeFee(amountUSD, defaultFeeFactor);

        // Update remaining USD for withdrawal
        amountUSD = IERC20Upgradeable(stablecoin).balanceOf(address(this));

        // Transfer USD*
        IERC20Upgradeable(stablecoin).safeTransfer(_recipient, amountUSD);
    }

    /// @notice Internal function for collecting UniV3 fees earned (does not swap to USD)
    /// @dev Assumes NFT liquidity already transferred in
    /// @param _tokenId Token ID of the liquidity position
    /// @param _maxSlippageFactor Acceptable slippage (9900 = 1%)
    /// @param _execData ExecutionData struct
    /// @return amount0 The amount of fees collected in Token0
    /// @return amount1 The amount of fees collected in Token1
    function _collectFees(
        uint256 _tokenId,
        uint256 _maxSlippageFactor,
        ExecutionData memory _execData
    ) internal returns (uint256 amount0, uint256 amount1) {
        // Collect fees
        INonfungiblePositionManager.CollectParams memory _params =
            INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        return nonfungiblePositionManager.collect(_params);
    }

    /* Utils */

    /// @notice Swaps USD to Token0 and Token1
    /// @param _execData The execution data (contains swap parameters)
    /// @return amount0Avail The amount of Token0 obtained. If no swap was needed, shows balance of Token0 instead
    /// @return amount1Avail Same except for Token1
    function _swapStablecoinToTokens(
        ExecutionData memory _execData,
        uint256 _maxSlippageFactor,
    ) internal returns (uint256 amount0Avail, uint256 amount1Avail) {
        // Get balance of USD after fees
        uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );

        // Get relative amounts of each token
        uint256 _amount1USDToSwap = _balUSD / (__execData.ratioToken0ToToken1 + 1e12);
        uint256 _amount0USDToSwap = _balUSD - _amount1USDToSwap;

        // Swap USD* into token0, token1 (if applicable)
        if (_execData.token0 != stablecoin) {
            amount0Avail = ISwapRouter(_execData.router).safeSwap(
                _amount0USDToSwap,
                _execData.exchRate0
                _maxSlippageFactor,
                _execData.pathToken0,
                address(this)
            );
        }

        if (_execData.token1 != stablecoin) {
            amount1Avail = ISwapRouter(_execData.router).safeSwap(
                _amount1USDToSwap,
                _execData.exchRate1
                _maxSlippageFactor,
                _execData.pathToken1,
                address(this)
            );
        }

        // If swaps were not performed (e.g. if token was the stablecoin), calculate the balance
        if (amount0Avail == 0) {
            amount0Avail = _getBalOfTokenFromPath(_execData.token0Path);
        }
        if (amount1Avail == 0) {
            amount1Avail = _getBalOfTokenFromPath(_execData.token1Path);
        }
    }

    /// @notice Swaps Token0 and Token1 into USD (if applicable)
    /// @param _execData The execution data (contains swap parameters)
    /// @param _amount0 Amount of Token0 to swap
    /// @param _amount1 Amount of Token1 to swap
    /// @param _maxSlippageFactor Slippage (1% = 9900)
    /// @return amountUSD The amount of USD obtained
    function _swapTokensToStablecoin(
        ExecutionData memory _execData,
        uint256 _amount0,
        uint256 _amount1,
        uint256 _maxSlippageFactor,
    ) internal returns (uint256 amountUSD) {
        // Swap token0, token1 to USD (if applicable)
        if (_execData.token0 != stablecoin) {
            amountUSD += ISwapRouter(_execData.router).safeSwap(
                _amount0,
                _execData.exchRate0 // TODO: Is it this or the inverse?
                _maxSlippageFactor,
                _execData.pathToken0,
                address(this)
            );
        }

        if (_execData.token1 != stablecoin) {
            amountUSD += ISwapRouter(_execData.router).safeSwap(
                _amount1,
                _execData.exchRate1
                _maxSlippageFactor,
                _execData.pathToken1,
                address(this)
            );
        }
    }

    /// @notice Takes a UniswapV3 multihop path and extracts the token balance
    /// @param _path The UniswapV3 multihop path
    /// @return bal The balance of the token at the decoded address
    function _getBalOfTokenFromPath(bytes calldata _path) internal returns (uint256 bal) {
        return IERC20Upgradeable(Utils.bytesToAddress(_path[:20]));
    }

    /* Proxy implementations */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

// TODO: Decoding bytesToAddress depends on direction!