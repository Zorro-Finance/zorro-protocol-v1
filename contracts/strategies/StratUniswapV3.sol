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
        bytes calldata _data
    ) external {
        // Unpack data
        (ExecutionData memory _execData) = abi.decode(
            _data,
            (ExecutionData)
        );

        // Safe transfer IN USD*
        IERC20(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            _amountUSD
        );

        // Collect fee on USD deposited
        _collectTradeFee(_amountUSD, defaultFeeFactor);

        // TODO: Should not call getTokenFromPath more than once for the same TX
        // TODO: Maybe don't need swapStablecoinToTokens and vice versa, but rather have reversal param

        // Swap USD to Token0, Token1
        (uint256 _amount0Avail, uint256 _amount1Avail) = _swapStablecoinToTokens(_execData, _maxSlippageFactor);

        {

            // Add liquidity
            INonfungiblePositionManager.MintParams memory _params =
            INonfungiblePositionManager.MintParams({
                token0: this.getTokenFromPath(_execData.pathToken0, -20),
                token1: this.getTokenFromPath(_execData.pathToken1, -20),
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
        uint256 _tokenId,
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes calldata _data
    ) external returns (uint128 liquidity) {
        // Unpack data
        (ExecutionData memory _execData) = abi.decode(
            _data,
            (ExecutionData)
        );

        // Safe transfer IN USD*
        IERC20(stablecoin).safeTransferFrom(
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
                IERC20(this.getTokenFromPath(_execData.pathToken0, -20)),
                IERC20(this.getTokenFromPath(_execData.pathToken1, -20)),
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
        bytes calldata _data
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
            _tokenId
        );

        // Decrease liquidity
        (uint256 _amount0liq, uint256 _amount1liq) = _decreaseLiquidity(_tokenId, _liquidity, _maxSlippageFactor, _execData);

        // Collect fees
        (uint256 _amount0Fees, uint256 _amount1Fees) = _collectFees(
            _execData.nfpManager,
            _tokenId,
            _maxSlippageFactor,
            _execData
        );

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
        _amountUSD = IERC20(stablecoin).balanceOf(address(this));

        // Transfer USD*
        IERC20(stablecoin).safeTransfer(_recipient, _amountUSD);
    }

    /// @inheritdoc	IStratUniswapV3
    function decreaseLiquidityUSD(
        uint256 _tokenId,
        uint128 _liquidity,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes calldata _data
    ) external returns (uint256 amountUSD) {
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
        amountUSD = IERC20(stablecoin).balanceOf(address(this));

        // Transfer USD*
        IERC20(stablecoin).safeTransfer(_recipient, amountUSD);
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
        address _recipient,
        bytes calldata _data
    ) external returns (uint256 amountUSD) {
        // Unpack data
        (ExecutionData memory _execData) = abi.decode(
            _data,
            (ExecutionData)
        );

        // Transfer liquidity IN
        INonfungiblePositionManager(_execData.nfpManager).safeTransferFrom(msg.sender, address(this), _tokenId);

        // Collect earned fees
        (uint256 _amount0, uint256 _amount1) = _collectFees(
            _execData.nfpManager,
            _tokenId,
            _maxSlippageFactor,
            _execData
        );

        // Swap to USD
        amountUSD = _swapTokensToStablecoin(_execData, _amount0, _amount1, _maxSlippageFactor);

        // Protocol Collect fee on USD deposited
        _collectTradeFee(amountUSD, defaultFeeFactor);

        // Update remaining USD for withdrawal
        amountUSD = IERC20(stablecoin).balanceOf(address(this));

        // Transfer USD*
        IERC20(stablecoin).safeTransfer(_recipient, amountUSD);
    }

    /// @notice Internal function for collecting UniV3 fees earned (does not swap to USD)
    /// @dev Assumes NFT liquidity already transferred in
    /// @param _nfpManager Address of the NonfungiblePositionManager contract
    /// @param _tokenId Token ID of the liquidity position
    /// @param _maxSlippageFactor Acceptable slippage (9900 = 1%)
    /// @param _execData ExecutionData struct
    /// @return amount0 The amount of fees collected in Token0
    /// @return amount1 The amount of fees collected in Token1
    function _collectFees(
        address _nfpManager,
        uint256 _tokenId,
        uint256 _maxSlippageFactor,
        ExecutionData calldata _execData
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

    /* Utils */

    /// @notice Swaps USD to Token0 and Token1
    /// @param _execData The execution data (contains swap parameters)
    /// @return amount0Avail The amount of Token0 obtained. If no swap was needed, shows balance of Token0 instead
    /// @return amount1Avail Same except for Token1
    function _swapStablecoinToTokens(
        ExecutionData memory _execData,
        uint256 _maxSlippageFactor
    ) internal returns (uint256 amount0Avail, uint256 amount1Avail) {
        // Get balance of USD after fees
        uint256 _balUSD = IERC20(stablecoin).balanceOf(
            address(this)
        );

        // Get relative amounts of each token
        uint256 _amount1USDToSwap = _balUSD / (_execData.ratioToken0ToToken1 + 1e12);
        uint256 _amount0USDToSwap = _balUSD - _amount1USDToSwap;

        // Get tokens
        address _token0 = this.getTokenFromPath(_execData.pathToken0, -20);
        address _token1 = this.getTokenFromPath(_execData.pathToken1, -20);

        // Swap USD* into token0, token1 (if applicable)
        if (_token0 != stablecoin) {
            amount0Avail = ISwapRouter(_execData.router).safeSwap(
                stablecoin,
                _amount0USDToSwap,
                _execData.exchRate0,
                _maxSlippageFactor,
                _execData.pathToken0,
                address(this)
            );
        }

        if (_token1 != stablecoin) {
            amount1Avail = ISwapRouter(_execData.router).safeSwap(
                stablecoin,
                _amount1USDToSwap,
                _execData.exchRate1,
                _maxSlippageFactor,
                _execData.pathToken1,
                address(this)
            );
        }

        // If swaps were not performed (e.g. if token was the stablecoin), calculate the balance
        if (amount0Avail == 0) {
            amount0Avail = IERC20(_token0).balanceOf(address(this));
        }
        if (amount1Avail == 0) {
            amount1Avail = IERC20(_token1).balanceOf(address(this));
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
        uint256 _maxSlippageFactor
    ) internal returns (uint256 amountUSD) {
        // Get tokens
        address _token0 = this.getTokenFromPath(_execData.pathToken0, 0);
        address _token1 = this.getTokenFromPath(_execData.pathToken1, 0);

        // Swap token0, token1 to USD (if applicable)
        if (_token0 != stablecoin) {
            amountUSD += ISwapRouter(_execData.router).safeSwap(
                _token0,
                _amount0,
                _execData.exchRate0, // TODO: Is it this or the inverse?
                _maxSlippageFactor,
                _execData.pathToken0,
                address(this)
            );
        }

        if (_token1 != stablecoin) {
            amountUSD += ISwapRouter(_execData.router).safeSwap(
                _token1,
                _amount1,
                _execData.exchRate1,
                _maxSlippageFactor,
                _execData.pathToken1,
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

    /// @notice Given a UniswapV3 multihop path and index of the token, decodes the address
    /// @dev Visibility is public so that functions with bytes memory can convert to call data to perform slice logic
    /// @param _path The UniswapV3 multihop path
    /// @param _index The index where the token exists in the multihop path
    /// @return token The address of the token
    function getTokenFromPath(bytes calldata _path, int256 _index) public returns (address token) {
        if (_index >= 0) {
            return Utils.bytesToAddress(_path[uint256(_index):uint256(_index)+20]);
        }
        return Utils.bytesToAddress(_path[_path.length-uint256(_index):]);
    }

    /* Proxy implementations */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}