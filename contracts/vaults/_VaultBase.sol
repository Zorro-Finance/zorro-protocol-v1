// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

import "../interfaces/Zorro/vaults/IVault.sol";

import "../libraries/PriceFeed.sol";

import "../libraries/SafeSwap.sol";

/// @title VaultBase
/// @notice Base contract for all vaults
abstract contract VaultBase is
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC20PermitUpgradeable,
    IVault
{
    /* Constants */

    uint256 public constant BP_DENOMINATOR = 10000; // Basis point denominator

    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using PriceFeed for AggregatorV3Interface;
    using SafeSwapUni for IAMMRouter02;

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _initVal A VaultInit struct
    /// @param _timelockOwner The owner address (timelock)
    /// @param _gov The governor address for non timelock admin functions
    function __VaultBase_init(
        VaultInit memory _initVal,
        address _timelockOwner,
        address _gov
    ) public onlyInitializing {
        // Set initial values
        treasury = _initVal.treasury;
        router = _initVal.router;
        stablecoin = _initVal.stablecoin;
        entranceFeeFactor = _initVal.entranceFeeFactor;
        withdrawFeeFactor = _initVal.withdrawFeeFactor;
        defaultSlippageFactor = 9900; // 1%

        // Transfer ownership to the timelock controller
        _transferOwnership(_timelockOwner);

        // Governor
        gov = _gov;

        // Call the ERC20 constructor to set initial values
        super.__ERC20_init("ZOR LP Vault", "ZLPV");

        // Call the ERC20Permit constructor with the same token name
        super.__ERC20Permit_init("ZOR LP Vault");
    }

    /* State */

    // Key wallets/contracts
    address public treasury;
    address public router;
    address public stablecoin;

    // Accounting & Fees
    uint256 public entranceFeeFactor;
    uint256 public withdrawFeeFactor;
    uint256 public defaultSlippageFactor;

    // Governor
    address public gov;

    // Token operations
    mapping(address => mapping(address => address[])) public swapPaths; // Swap paths. Mapping: start address => end address => address array describing swap path
    mapping(address => mapping(address => uint16)) public swapPathLength; // Swap path lengths. Mapping: start address => end address => path length
    mapping(address => AggregatorV3Interface) public priceFeeds; // Price feeds. Mapping: token address => price feed address (AggregatorV3Interface implementation)

    // Gasless
    mapping(address => CountersUpgradeable.Counter) private _nonces;

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

    /// @notice Sets the default slippage factor
    /// @param _slippageFactor The slippage tolerance (9900 = 1%)
    function setDefaultSlippageFactor(
        uint256 _slippageFactor
    ) external onlyOwner {
        defaultSlippageFactor = _slippageFactor;
    }

    /// @notice Sets swap paths for AMM swaps
    /// @param _path The array of tokens representing the swap path
    function setSwapPaths(address[] memory _path) external onlyOwner {
        _setSwapPaths(_path);
    }

    /// @notice Internal function for setting swap paths
    /// @param _path The array of tokens representing the swap path
    function _setSwapPaths(address[] memory _path) internal {
        // Check to make sure path not empty
        if (_path.length == 0) {
            return;
        }

        // Prep
        address _startToken = _path[0];
        address _endToken = _path[_path.length - 1];
        // Set path mapping
        swapPaths[_startToken][_endToken] = _path;

        // Set length
        swapPathLength[_startToken][_endToken] = uint16(_path.length);
    }

    /// @notice Sets price feed for a given token
    /// @param _token The token that the price feed is for
    /// @param _priceFeedAddress The address of the Chainlink compatible price feed
    function setPriceFeed(
        address _token,
        address _priceFeedAddress
    ) external onlyOwner {
        _setPriceFeed(_token, _priceFeedAddress);
    }

    /// @notice Internal function for setting the price feed
    /// @param _token The token that the price feed is for
    /// @param _priceFeedAddress The address of the Chainlink compatible price feed
    function _setPriceFeed(address _token, address _priceFeedAddress) internal {
        priceFeeds[_token] = AggregatorV3Interface(_priceFeedAddress);
    }

    /// @notice Sets governor address
    /// @param _gov The address for the governor
    function setGov(address _gov) external onlyOwner {
        gov = _gov;
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
