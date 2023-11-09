// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./_VaultBase.sol";

import "../libraries/LPUtility.sol";

import "hardhat/console.sol"; // TODO: Get rid of this

/// @title VaultUniswapV2
/// @notice Vault contract for standard UniswapV2 based investment strategies
contract VaultUniswapV2 is VaultBase {
    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeSwapUni for IUniswapV2Router02;
    using LPUtility for IUniswapV2Router02;

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
    /// @param _data Encoding format: {pool}{token0}{token1}
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
        (address _pool, address _token0, address _token1) = abi.decode(
            _data,
            (address, address, address)
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
            if (_token0 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balUSD / 2,
                    swapPaths[stablecoin][_token0],
                    priceFeeds[stablecoin],
                    priceFeeds[_token0],
                    _maxSlippageFactor,
                    address(this)
                );
            }

            if (_token1 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balUSD / 2,
                    swapPaths[stablecoin][_token1],
                    priceFeeds[stablecoin],
                    priceFeeds[_token1],
                    _maxSlippageFactor,
                    address(this)
                );
            }
        }


        {
            // Get token balances
            uint256 _balToken0 = IERC20Upgradeable(_token0).balanceOf(
                address(this)
            );
            uint256 _balToken1 = IERC20Upgradeable(_token1).balanceOf(
                address(this)
            );

            // Add liquidity
            IUniswapV2Router02(router).joinPool(
                _token0,
                _token1,
                _balToken0,
                _balToken1,
                _maxSlippageFactor,
                _recipient
            );
        }

        // Emit log
        emit DepositUSD(_pool, _amountUSD, _maxSlippageFactor);
    }

    /// @inheritdoc	IVault
    /// @param _data Encoding format: {pool}{token0}{token1}
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
        (address _pool, address _token0, address _token1) = abi.decode(
            _data,
            (address, address, address)
        );

        {
            console.log("lp shares requested to withdrawUSD: ", _lpShares, _source, address(this));

            uint256 _currAllowance = IERC20Upgradeable(_pool).allowance(_source, address(this));
            console.log("current allowance: ", _currAllowance);
        }

        // Safe Transfer LP tokens IN
        IERC20Upgradeable(_pool).safeTransferFrom(
            _source,
            address(this),
            _lpShares
        );

        // Remove liquidity
        IUniswapV2Router02(router).exitPool(
            _lpShares,
            _pool,
            _token0,
            _token1,
            _maxSlippageFactor,
            address(this)
        );

        {

            // Calc balance of Tokens 0,1
            uint256 _balToken0 = IERC20Upgradeable(_token0).balanceOf(
                address(this)
            );
            uint256 _balToken1 = IERC20Upgradeable(_token1).balanceOf(
                address(this)
            );

            // Swap Tokens 0,1 to USD*
            if (_token0 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balToken0,
                    swapPaths[_token0][stablecoin],
                    priceFeeds[_token0],
                    priceFeeds[stablecoin],
                    _maxSlippageFactor,
                    address(this)
                );
            }
            if (_token1 != stablecoin) {
                IUniswapV2Router02(router).safeSwap(
                    _balToken1,
                    swapPaths[_token1][stablecoin],
                    priceFeeds[_token1],
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
        emit WithdrawUSD(_pool, _balUSD, _maxSlippageFactor);
    }

    /* Meta Transactions */

    /// @notice Initializes the EIP712 contract with a unique name and version combination
    function _initEIP712() internal override {
        EIP712Upgradeable.__EIP712_init("ZVault UniswapV2", "1");
    }

    /* Proxy implementations */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
