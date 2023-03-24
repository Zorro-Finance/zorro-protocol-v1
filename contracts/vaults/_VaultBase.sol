// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

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
    IVault
{
    /* Constants */

    uint256 BP_DENOMINATOR = 10000; // Basis point denominator

    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using PriceFeed for AggregatorV3Interface;
    using SafeSwapUni for IAMMRouter02;

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _initVal A VaultInit struct
    /// @param _timelockOwner The owner address (timelock)
    function initialize(
        VaultInit memory _initVal,
        address _timelockOwner
    ) public virtual initializer {
        // Set initial values
        treasury = _initVal.treasury;
        router = _initVal.router;
        entranceFeeFactor = _initVal.entranceFeeFactor;
        withdrawFeeFactor = _initVal.withdrawFeeFactor;
        defaultSlippageFactor = 9900; // 1%

        // Transfer ownership to the timelock controller
        _transferOwnership(_timelockOwner);

        // Call the ERC20 constructor to set initial values
        super.__ERC20_init("ZOR LP Vault", "ZLPV");
    }

    /* State */

    // Key wallets/contracts
    address public treasury;
    address public router;

    // Accounting & Fees
    uint256 public entranceFeeFactor;
    uint256 public withdrawFeeFactor;
    uint256 public defaultSlippageFactor;

    // Token operations
    mapping(address => mapping(address => address[])) public swapPaths; // Swap paths. Mapping: start address => end address => address array describing swap path
    mapping(address => mapping(address => uint16)) public swapPathLength; // Swap path lengths. Mapping: start address => end address => path length
    mapping(address => AggregatorV3Interface) public priceFeeds; // Price feeds. Mapping: token address => price feed address (AggregatorV3Interface implementation)

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
    function setPriceFeed(address _token, address _priceFeedAddress) external onlyOwner {
        _setPriceFeed(_token, _priceFeedAddress);
    }

    /// @notice Internal function for setting the price feed
    /// @param _token The token that the price feed is for
    /// @param _priceFeedAddress The address of the Chainlink compatible price feed
    function _setPriceFeed(address _token, address _priceFeedAddress) internal {
        priceFeeds[_token] = AggregatorV3Interface(_priceFeedAddress);
    }

    /* Utilities */

    /// @notice Safely swaps from one token to another
    /// @dev Tries to use a Chainlink price feed oracle if one exists
    /// @param _amountIn The quantity of the origin token to swap
    /// @param _startToken The origin token (to swap FROM)
    /// @param _endToken The destination token (to swap TO)
    /// @param _maxSlippageFactor The max slippage factor tolerated (9900 = 1%)
    /// @param _destination Where to send the swapped token to
    function _safeSwap(
        uint256 _amountIn,
        address _startToken,
        address _endToken,
        uint256 _maxSlippageFactor,
        address _destination
    ) internal {
        // Get exchange rates of each token
        uint256[] memory _priceTokens = new uint256[](2);
        AggregatorV3Interface _priceFeed0 = priceFeeds[_startToken];
        AggregatorV3Interface _priceFeed1 = priceFeeds[_endToken];

        // If price feed exists, use latest round data. If not, assign zero
        if (address(_priceFeed0) == address(0)) {
            _priceTokens[0] = 0;
        } else {
            _priceTokens[0] = _priceFeed0.getExchangeRate();
        }
        if (address(_priceFeed1) == address(0)) {
            _priceTokens[1] = 0;
        } else {
            _priceTokens[1] = _priceFeed1.getExchangeRate();
        }

        // Get decimals
        uint8[] memory _decimals = new uint8[](2);
        _decimals[0] = ERC20Upgradeable(_startToken).decimals();
        _decimals[0] = ERC20Upgradeable(_endToken).decimals();

        // Safe transfer
        IERC20Upgradeable(_startToken).safeIncreaseAllowance(router, _amountIn);

        // Perform swap
        IAMMRouter02(router).safeSwap(
            _amountIn,
            _priceTokens,
            _maxSlippageFactor,
            swapPaths[_startToken][_endToken],
            _decimals,
            _destination,
            block.timestamp + 300
        );
    }

    /// @notice Internal function for adding liquidity to the pool of this contract
    /// @param _token0 Address of the first token
    /// @param _token1 Address of the second token
    /// @param _token0Amt Quantity of Token0 to add
    /// @param _token1Amt Quantity of Token1 to add
    /// @param _maxSlippageFactor The max slippage allowed for swaps. 1000 = 0 %, 995 = 0.5%, etc.
    /// @param _recipient The recipient of the LP token
    function _joinPool(
        address _token0,
        address _token1,
        uint256 _token0Amt,
        uint256 _token1Amt,
        uint256 _maxSlippageFactor,
        address _recipient
    ) internal {
        // Approve spending
        IERC20Upgradeable(_token0).safeIncreaseAllowance(router, _token0Amt);
        IERC20Upgradeable(_token1).safeIncreaseAllowance(router, _token1Amt);

        // Add liquidity
        IAMMRouter02(router).addLiquidity(
            _token0,
            _token1,
            _token0Amt,
            _token1Amt,
            (_token0Amt * _maxSlippageFactor) / BP_DENOMINATOR,
            (_token1Amt * _maxSlippageFactor) / BP_DENOMINATOR,
            _recipient,
            block.timestamp + 600
        );
    }

    /// @notice Internal function for removing liquidity from the pool of this contract
    /// @dev NOTE: Assumes LP token is already on contract
    /// @param _amountLP The amount of LP tokens to remove
    /// @param _maxSlippageFactor The max slippage allowed for swaps. 10000 = 0 %, 9950 = 0.5%, etc.
    /// @param _recipient The recipient of the underlying tokens upon pool exit
    function _exitPool(
        uint256 _amountLP,
        address _pool,
        address _token0,
        address _token1,
        uint256 _maxSlippageFactor,
        address _recipient
    ) internal {
        // Init
        uint256 _amount0Min;
        uint256 _amount1Min;

        {
            _amount0Min = _calcMinAmt(
                _amountLP,
                _token0,
                _pool,
                _maxSlippageFactor
            );
            _amount1Min = _calcMinAmt(
                _amountLP,
                _token1,
                _pool,
                _maxSlippageFactor
            );
        }

        // Approve
        IERC20Upgradeable(_pool).safeIncreaseAllowance(
                router,
                _amountLP
            );

        // Remove liquidity
        IAMMRouter02(router).removeLiquidity(
            _token0,
            _token1,
            _amountLP,
            _amount0Min,
            _amount1Min,
            _recipient,
            block.timestamp + 300
        );
    }

    /// @notice Calculates minimum amount out for exiting LP pool
    /// @param _amountLP LP token qty
    /// @param _token Address of one of the tokens in the pair
    /// @param _pool Address of LP pair
    /// @param _slippageFactor Slippage (9900 = 1% etc.)
    function _calcMinAmt(
        uint256 _amountLP,
        address _token,
        address _pool,
        uint256 _slippageFactor
    ) internal view returns (uint256) {
        // Get total supply and calculate min amounts desired based on slippage
        uint256 _totalSupply = IERC20Upgradeable(_pool).totalSupply();

        // Get balance of token in pool
        uint256 _balance = IERC20Upgradeable(_token).balanceOf(_pool);

        // Return min token amount out
        return
            (_amountLP * _balance * _slippageFactor) /
            (BP_DENOMINATOR * _totalSupply);
    }

    /* Maintenance Functions */

    /// @notice Pause contract
    function pause() public virtual onlyOwner {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() public virtual onlyOwner {
        _unpause();
    }
}
