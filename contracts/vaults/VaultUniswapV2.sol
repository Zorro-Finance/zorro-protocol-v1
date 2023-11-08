// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../interfaces/Zorro/vaults/IVaultUniswapV2.sol";

import "./_VaultBase.sol";

import "../libraries/LPUtility.sol";

/// @title VaultUniswapV2
/// @notice Vault contract for standard UniswapV2 based investment strategies
contract VaultUniswapV2 is VaultBase, IVaultUniswapV2 {
    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeSwapUni for IUniswapV2Router02;
    using LPUtility for IUniswapV2Router02;

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _initVal A VaultUniswapV2Init struct
    /// @param _timelockOwner The owner address (timelock)
    /// @param _gov The governor address for non timelock admin functions
    function initialize(
        VaultUniswapV2Init memory _initVal,
        address _timelockOwner,
        address _gov
    ) public initializer {
        // Set contract config
        asset = _initVal.asset;
        token0 = _initVal.token0;
        token1 = _initVal.token1;
        pool = _initVal.pool;

        // Set swap paths
        _setSwapPaths(_initVal.swapPaths.stablecoinToToken0);
        _setSwapPaths(_initVal.swapPaths.stablecoinToToken1);
        _setSwapPaths(_initVal.swapPaths.token0ToStablecoin);
        _setSwapPaths(_initVal.swapPaths.token1ToStablecoin);
        _setSwapPaths(_initVal.swapPaths.rewardsToToken0);
        _setSwapPaths(_initVal.swapPaths.rewardsToToken1);

        // Set price feeds
        _setPriceFeed(token0, _initVal.priceFeeds.token0);
        _setPriceFeed(token1, _initVal.priceFeeds.token1);
        _setPriceFeed(WETH, _initVal.priceFeeds.eth);
        _setPriceFeed(stablecoin, _initVal.priceFeeds.stablecoin);

        // Call parent constructor
        super.__VaultBase_init(_initVal.baseInit, _timelockOwner, _gov);
    }

    /* State */

    // Key tokens, contracts, and config
    address public asset;
    address public token0;
    address public token1;
    address public pool;

    /* Setters */

    /// @notice Sets key tokens/contract addresses for this contract
    /// @param _asset The main asset token
    /// @param _token0 The first token of the LP pair for this contract
    /// @param _token1 The second token of the LP pair for this contract
    /// @param _weth Wrapped ETH token (equivalent native token (e.g. WAVAX, WBNB etc.))
    /// @param _pool The LP pair address
    function setTokens(
        address _asset,
        address _token0,
        address _token1,
        address _weth,
        address _pool
    ) external onlyOwner {
        asset = _asset;
        token0 = _token0;
        token1 = _token1;
        WETH = _weth;
        pool = _pool;
    }

    /* Functions */

    /// @inheritdoc	IVault
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _recipient
    ) external {
        // Call internal deposit func
        _depositUSD(
            _amountUSD,
            _maxSlippageFactor,
            _recipient,
            0, // No relay reimbursement needed as this is not a permit deposit
            address(0) // Dummy address for reimbursement (see docs)
        );
    }

    /// @inheritdoc VaultBase
    function _depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _account,
        uint256 _relayFee,
        address _relayer
    ) internal override nonReentrant {
        // Safe transfer IN USD*
        IERC20Upgradeable(stablecoin).safeTransferFrom(
            _account,
            address(this),
            _amountUSD
        );

        // Convert USD to native ETH for gas + xc tx and refund relayer (if applicable)
        if (_relayFee > 0) {
            _recoupXCFeeFromUSD(_relayFee, _relayer);
        }

        // Collect fee on USD deposited
        _collectTradeFee(_amountUSD, entranceFeeFactor);

        // Get balance of USD after fees
        uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );

        // Swap USD* into token0, token1 (if applicable)
        if (token0 != stablecoin) {
            IUniswapV2Router02(router).safeSwap(
                _balUSD / 2,
                swapPaths[stablecoin][token0],
                priceFeeds[stablecoin],
                priceFeeds[token0],
                _maxSlippageFactor,
                address(this)
            );
        }

        if (token1 != stablecoin) {
            IUniswapV2Router02(router).safeSwap(
                _balUSD / 2,
                swapPaths[stablecoin][token1],
                priceFeeds[stablecoin],
                priceFeeds[token1],
                _maxSlippageFactor,
                address(this)
            );
        }

        // Get token balances
        uint256 _balToken0 = IERC20Upgradeable(token0).balanceOf(address(this));
        uint256 _balToken1 = IERC20Upgradeable(token1).balanceOf(address(this));

        // Add liquidity
        IUniswapV2Router02(router).joinPool(
            token0,
            token1,
            _balToken0,
            _balToken1,
            _maxSlippageFactor,
            _account
        );

        // Emit log
        emit DepositUSD(pool, _amountUSD, _maxSlippageFactor);
    }

    /// @inheritdoc	IVault
    function withdrawUSD(uint256 _lpShares, uint256 _maxSlippageFactor) external {
        // Call internal withdrawal function
        // Note: 0 for reimbursement because this is not a permit transaction
        _withdrawUSD(_lpShares, _maxSlippageFactor, _msgSender(), 0, address(0));
    }

    /// @inheritdoc VaultBase
    /// @param _lpShares The amount of LP shares to withdraw
    function _withdrawUSD(
        uint256 _lpShares,
        uint256 _maxSlippageFactor,
        address _account,
        uint256 _relayFee,
        address _relayer
    ) internal override nonReentrant {
        // Safe Transfer LP tokens IN
        IERC20Upgradeable(asset).safeTransferFrom(
            _account,
            address(this),
            _lpShares
        );

        // Remove liquidity
        IUniswapV2Router02(router).exitPool(
            _lpShares,
            pool,
            token0,
            token1,
            _maxSlippageFactor,
            address(this)
        );

        // Calc balance of Tokens 0,1
        uint256 _balToken0 = IERC20Upgradeable(token0).balanceOf(address(this));
        uint256 _balToken1 = IERC20Upgradeable(token1).balanceOf(address(this));

        // Swap Tokens 0,1 to USD*
        if (token0 != stablecoin) {
            IUniswapV2Router02(router).safeSwap(
                _balToken0,
                swapPaths[token0][stablecoin],
                priceFeeds[token0],
                priceFeeds[stablecoin],
                _maxSlippageFactor,
                address(this)
            );
        }
        if (token1 != stablecoin) {
            IUniswapV2Router02(router).safeSwap(
                _balToken1,
                swapPaths[token1][stablecoin],
                priceFeeds[token1],
                priceFeeds[stablecoin],
                _maxSlippageFactor,
                address(this)
            );
        }

        // Get balances of USD*
        uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );

        // Collect fee on USD deposited
        _collectTradeFee(_balUSD, withdrawFeeFactor);

        // Reimburse fee (if applicable)
        if (_relayFee > 0) {
            // Recoup from USD balance
            _recoupXCFeeFromUSD(_relayFee, _relayer);

            // Update remaining USD for withdrawal
            _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
                address(this)
            );
        }

        // Transfer USD*
        IERC20Upgradeable(stablecoin).safeTransfer(_account, _balUSD);

        // Emit log
        emit WithdrawUSD(pool, _balUSD, _maxSlippageFactor);
    }

    /* Meta Transactions */

    /// @notice Initializes the EIP712 contract with a unique name and version combination
    function _initEIP712() internal override {
        EIP712Upgradeable.__EIP712_init("ZVault UniswapV2", "1");
    }

    /* Proxy implementations */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
