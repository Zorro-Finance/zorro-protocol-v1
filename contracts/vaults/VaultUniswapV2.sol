// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./_VaultBase.sol";

import "../libraries/LPUtility.sol";

/// @title VaultUniswapV2
/// @notice Vault contract for standard UniswapV2 based investment strategies
contract VaultUniswapV2 is VaultBase {
    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeSwapUni for IUniswapV2Router02;
    using LPUtility for IUniswapV2Router02;

    /* Structs */
    struct PoolData {
        address router;
        address pool;
        address token0;
        address token1;
        address[] swapPathToken0ToStablecoin;
        address[] swapPathToken1ToStablecoin;
    }

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _initVal A VaultAMMInit struct
    /// @param _timelockOwner The owner address (timelock)
    /// @param _gov The governor address for non timelock admin functions
    function initialize(
        VaultInit memory _initVal,
        address _timelockOwner,
        address _gov
    ) public initializer {
        // Call parent constructor
        super.__VaultBase_init(_initVal, _timelockOwner, _gov);
    }

    /* Functions */

    /// @inheritdoc	IVault
    /// @param _data Encoding format: {router}{pool}{token0}{token1}{swapPathT0ToStablecoin}{swapPathT1ToStablecoin}
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _source,
        address _recipient,
        bytes memory _data
    ) external {
        // Call internal deposit func
        _depositUSD(
            _amountUSD,
            _maxSlippageFactor,
            _source,
            _recipient,
            0, // No relay reimbursement needed as this is not a permit deposit
            address(0), // Dummy address for reimbursement (see docs)
            _data
        );
    }

    /// @inheritdoc VaultBase
    function _depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _source,
        address _recipient,
        uint256 _relayFee,
        address _relayer,
        bytes memory _data
    ) internal override nonReentrant {
        // Unpack data
        (PoolData memory _poolData) = abi.decode(
            _data,
            (PoolData)
        );

        // Safe transfer IN USD*
        IERC20Upgradeable(stablecoin).safeTransferFrom(
            _source,
            address(this),
            _amountUSD
        );

        // Convert USD to native ETH for gas + xc tx and refund relayer (if applicable)
        if (_relayFee > 0) {
            _recoupXCFeeFromUSD(_relayFee, _relayer);
        }

        // Collect fee on USD deposited
        _collectTradeFee(_amountUSD, entranceFeeFactor);

        {
            // Get balance of USD after fees
            uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
                address(this)
            );

            // Swap USD* into token0, token1 (if applicable)
            if (_poolData.token0 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balUSD / 2,
                    _reverseSwapPath(_poolData.swapPathToken0ToStablecoin),
                    priceFeeds[stablecoin],
                    priceFeeds[_poolData.token0],
                    _maxSlippageFactor,
                    address(this)
                );
            }

            if (_poolData.token1 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balUSD / 2,
                    _reverseSwapPath(_poolData.swapPathToken1ToStablecoin),
                    priceFeeds[stablecoin],
                    priceFeeds[_poolData.token1],
                    _maxSlippageFactor,
                    address(this)
                );
            }
        }


        {
            // Get token balances
            uint256 _balToken0 = IERC20Upgradeable(_poolData.token0).balanceOf(
                address(this)
            );
            uint256 _balToken1 = IERC20Upgradeable(_poolData.token1).balanceOf(
                address(this)
            );

            // Add liquidity
            IUniswapV2Router02(_poolData.router).joinPool(
                _poolData.token0,
                _poolData.token1,
                _balToken0,
                _balToken1,
                _maxSlippageFactor,
                _recipient
            );
        }

        // Emit log
        emit DepositUSD(_poolData.pool, _amountUSD, _maxSlippageFactor);
    }

    /// @inheritdoc	IVault
    /// @param _data Encoding format: {router}{pool}{token0}{token1}{swapPathT0ToStablecoin}{swapPathT1ToStablecoin}
    function withdrawUSD(
        uint256 _lpShares,
        uint256 _maxSlippageFactor,
        address _source,
        address _recipient,
        bytes memory _data
    ) external {
        // Call internal withdrawal function
        // Note: 0 for reimbursement because this is not a permit transaction
        _withdrawUSD(
            _lpShares,
            _maxSlippageFactor,
            _source,
            _recipient,
            0,
            address(0),
            _data
        );
    }

    /// @inheritdoc VaultBase
    /// @param _lpShares The amount of LP shares to withdraw
    function _withdrawUSD(
        uint256 _lpShares,
        uint256 _maxSlippageFactor,
        address _source,
        address _recipient,
        uint256 _relayFee,
        address _relayer,
        bytes memory _data
    ) internal override nonReentrant {
        // Unpack data
        (PoolData memory _poolData) = abi.decode(
            _data,
            (PoolData)
        );

        // Safe Transfer LP tokens IN
        IERC20Upgradeable(_poolData.pool).safeTransferFrom(
            _source,
            address(this),
            _lpShares
        );

        // Remove liquidity
        IUniswapV2Router02(_poolData.router).exitPool(
            _lpShares,
            _poolData.pool,
            _poolData.token0,
            _poolData.token1,
            _maxSlippageFactor,
            address(this)
        );

        {

            // Calc balance of Tokens 0,1
            uint256 _balToken0 = IERC20Upgradeable(_poolData.token0).balanceOf(
                address(this)
            );
            uint256 _balToken1 = IERC20Upgradeable(_poolData.token1).balanceOf(
                address(this)
            );

            // Swap Tokens 0,1 to USD*
            if (_poolData.token0 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balToken0,
                    _poolData.swapPathToken0ToStablecoin,
                    priceFeeds[_poolData.token0],
                    priceFeeds[stablecoin],
                    _maxSlippageFactor,
                    address(this)
                );
            }
            if (_poolData.token1 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balToken1,
                    _poolData.swapPathToken1ToStablecoin,
                    priceFeeds[_poolData.token1],
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


        // Reimburse fee (if applicable)
        if (_relayFee > 0) {
            // Recoup from USD balance
            _recoupXCFeeFromUSD(_relayFee, _relayer);

        }

        // Update remaining USD for withdrawal
        _balUSD = IERC20Upgradeable(stablecoin).balanceOf(address(this));

        // Transfer USD*
        IERC20Upgradeable(stablecoin).safeTransfer(_recipient, _balUSD);

        // Emit log
        emit WithdrawUSD(_poolData.pool, _balUSD, _maxSlippageFactor);
    }

    /* Meta Transactions */

    /// @notice Initializes the EIP712 contract with a unique name and version combination
    function _initEIP712() internal override {
        EIP712Upgradeable.__EIP712_init("ZVault UniswapV2", "1");
    }

    /* Proxy implementations */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
