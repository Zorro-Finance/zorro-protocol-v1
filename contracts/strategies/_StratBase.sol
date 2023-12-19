// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

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

    using SafeERC20 for IERC20;
    using SafeSwapUni for ISwapRouter;

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _timelockOwner The owner address (timelock)
    /// @param _gov The governor address for non timelock admin functions
    /// @param _initVal A StratInit struct
    function __StratBase_init(
        address _timelockOwner,
        address _gov,
        StratInit calldata _initVal
    ) public onlyInitializing {
        // Set initial values
        treasury = _initVal.treasury;
        stablecoin = _initVal.stablecoin;
        defaultFeeFactor = _initVal.defaultFeeFactor;

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
        require(_msgSender() == gov, "ZORRO: !gov");
        _;
    }

    /* Setters */

    /// @notice Sets treasury wallet address
    /// @param _treasury The address for the treasury contract/wallet
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /// @notice Sets the fee params
    /// @param _defaultFeeFactor The default fee (9900 = 1%)
    function setFeeParams(
        uint256 _defaultFeeFactor
    ) external onlyOwner {
        defaultFeeFactor = _defaultFeeFactor;
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
            IERC20(stablecoin).safeTransfer(
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
