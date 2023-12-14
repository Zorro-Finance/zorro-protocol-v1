// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/Zorro/strategies/IStrat.sol";

import "../libraries/SafeSwap.sol";

/// @title StratBase
/// @notice Base contract for all strategies
abstract contract StratBase is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IStrat,
    UUPSUpgradeable
{
    /* Constants */

    uint256 public constant BP_DENOMINATOR = 10000; // Basis point denominator

    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeSwapUni for IUniswapV2Router02;

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _initVal A StratInit struct
    /// @param _timelockOwner The owner address (timelock)
    /// @param _gov The governor address for non timelock admin functions
    function __StratBase_init(
        StratInit memory _initVal,
        address _timelockOwner,
        address _gov
    ) public onlyInitializing {
        // Set initial values
        treasury = _initVal.treasury;
        stablecoin = _initVal.stablecoin;
        entranceFeeFactor = _initVal.entranceFeeFactor;
        withdrawFeeFactor = _initVal.withdrawFeeFactor;

        // Transfer ownership to the timelock controller
        _transferOwnership(_timelockOwner);

        // Governor
        gov = _gov;
    }

    /* State */

    // Key wallets/contracts
    address public treasury;
    address public stablecoin;

    // Accounting & Fees
    uint256 public entranceFeeFactor;
    uint256 public withdrawFeeFactor;

    // Governor
    address public gov;

    /* Modifiers */

    modifier onlyAllowGov() {
        require(_msgSender() == gov, "!gov");
        _;
    }

    /* Setters */

    /// @notice Sets treasury wallet address
    /// @param _treasury The address for the treasury contract/wallet
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /// @notice Sets the fee params
    /// @param _entranceFeeFactor The deposit fee (9900 = 1%)
    /// @param _withdrawFeeFeeFactor The withdrawal fee (9900 = 1%)
    function setFeeParams(
        uint256 _entranceFeeFactor,
        uint256 _withdrawFeeFeeFactor
    ) external onlyOwner {
        entranceFeeFactor = _entranceFeeFactor;
        withdrawFeeFactor = _withdrawFeeFeeFactor;
    }

    /// @notice Sets governor address
    /// @param _gov The address for the governor
    function setGov(address _gov) external onlyOwner {
        gov = _gov;
    }

    /// @notice Collects protocol trade fees and sends to treasury
    /// @param _principalAmt The amount to take the fees off of
    /// @param _feeFactor The fee factor (e.g. entranceFeeFactor, withdrawFeeFactor)
    function _collectTradeFee(
        uint256 _principalAmt,
        uint256 _feeFactor
    ) internal {
        // Send fee to treasury if a fee is set
        if (_feeFactor < BP_DENOMINATOR) {
            IERC20Upgradeable(stablecoin).safeTransfer(
                treasury,
                (_principalAmt * (BP_DENOMINATOR - _feeFactor)) / BP_DENOMINATOR
            );
        }
    }

    /* Deposits/Withdrawals (abstract) */

    /// @notice Internal function for depositing USD
    /// @param _amountUSD Amount of USD to deposit
    /// @param _maxSlippageFactor Max slippage tolerant (9900 = 1%)
    /// @param _source Where the USD should be transfered from (requires approval)
    /// @param _recipient Where the received tokens should be sent to
    /// @param _relayFee Gas that needs to be compensated to relayer. Set to 0 if n/a
    /// @param _relayer Where to send gas compensation
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.)
    function _depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _source,
        address _recipient,
        uint256 _relayFee,
        address _relayer,
        bytes memory _data
    ) internal virtual;

    /// @notice Internal function for USD withdrawals
    /// @param _amount The quantity to withdraw
    /// @param _maxSlippageFactor Slippage tolerance (9900 = 1%)
    /// @param _source Where the investment tokens (e.g. LP tokens, shares, etc.) should be transfered from (requires approval)
    /// @param _recipient Where the withdrawn USD should be sent to
    /// @param _relayFee Gas that needs to be compensated to relayer. Set to 0 if n/a
    /// @param _relayer Where to send gas compensation
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.)
    function _withdrawUSD(
        uint256 _amount,
        uint256 _maxSlippageFactor,
        address _source,
        address _recipient,
        uint256 _relayFee,
        address _relayer,
        bytes memory _data
    ) internal virtual;

    /* Maintenance Functions */

    /// @notice Pause contract
    function pause() public virtual onlyAllowGov {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() public virtual onlyAllowGov {
        _unpause();
    }
}
