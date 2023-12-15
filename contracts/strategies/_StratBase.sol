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
    uint256 public defaultFeeFactor;

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
