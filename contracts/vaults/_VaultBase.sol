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

import "../libraries/SafeSwapETH.sol";

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
    bytes32 private constant _PERMIT_TRANSACT_USD_TYPEHASH =
        keccak256(
            "TransactUSDPermit(address account,uint256 amount,uint256 maxMarketMovement,uint8 direction,uint256 nonce,uint256 deadline)"
        );

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
        WETH = _initVal.tokenWETH;
        entranceFeeFactor = _initVal.entranceFeeFactor;
        withdrawFeeFactor = _initVal.withdrawFeeFactor;
        defaultSlippageFactor = 9900; // 1%

        // Transfer ownership to the timelock controller
        _transferOwnership(_timelockOwner);

        // Governor
        gov = _gov;

        // Call the ERC20 constructor to set initial values
        super.__ERC20_init("ZOR LP Vault", "ZLPV");

        // Call the ERC20Permit constructor with the same token name (must match above)
        super.__ERC20Permit_init("ZOR LP Vault");
    }

    /* State */

    // Key wallets/contracts
    address public treasury;
    address public router;
    address public stablecoin;
    address public WETH;

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

    /* Meta Txs */

    /// @inheritdoc	IVault
    function transactUSDWithPermit(
        address _account,
        uint256 _amount,
        uint256 _maxSlippageFactor,
        uint8 _direction,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external whenNotPaused {
        // Init
        uint256 _startGas = gasleft();

        // Check deadline
        require(block.timestamp <= _deadline, "ZorroVault: expired deadline");

        // Calculate hash of typed data
        bytes32 _structHash = keccak256(
            abi.encode(
                _PERMIT_TRANSACT_USD_TYPEHASH,
                _account,
                _amount,
                _maxSlippageFactor,
                _direction,
                _useNonce(_account),
                _deadline
            )
        );
        bytes32 _hash = _hashTypedDataV4(_structHash);

        // Extract signer from signature
        address _signer = ECDSAUpgradeable.recover(_hash, _v, _r, _s);

        // Check if signer matches sender
        require(_signer == _account, "ZorroVault: invalid signature");

        // Allow transaction through
        if (_direction == 0) {
            // Deposit
            _depositUSD(_amount, _maxSlippageFactor, _account, _startGas * tx.gasprice, _msgSender());
        } else if (_direction == 1) {
            // Withdraw
            _withdrawUSD(_amount, _maxSlippageFactor, _account, _startGas * tx.gasprice, _msgSender());
        } else {
            revert("ZorroVault: invalid dir");
        }
    }

    /// @notice Swaps USD to ETH to compensate relayer for XC fee spent
    /// @param _fee The amount of ETH used for the XC fee
    /// @param _relayer The address of the relayer to compensate
    function _recoupXCFeeFromUSD(uint256 _fee, address _relayer) internal {
        // Prep swap path
        address[] memory _swapPath = new address[](2);
        _swapPath[0] = stablecoin;
        _swapPath[1] = WETH;

        // Swap USD to ETH to the relayer
        SafeSwapUniETH.safeSwapToETH(
            router,
            _fee,
            _swapPath,
            priceFeeds[stablecoin],
            priceFeeds[WETH],
            defaultSlippageFactor,
            _relayer
        );
    }

    /* Deposits/Withdrawals (abstract) */

    /// @notice Internal function for depositing USD
    /// @param _amountUSD Amount of USD to deposit
    /// @param _maxSlippageFactor Max slippage tolerant (9900 = 1%)
    /// @param _account Where to draw USD funds from
    /// @param _relayFee Gas that needs to be compensated to relayer. Set to 0 if n/a
    /// @param _relayer Where to send gas compensation
    function _depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _account,
        uint256 _relayFee,
        address _relayer
    ) internal virtual;

    /// @notice Internal function for USD withdrawals
    /// @param _shares The number of shares to withdraw
    /// @param _maxSlippageFactor Slippage tolerance (9900 = 1%)
    /// @param _account The account holding the shares to withdraw
    /// @param _relayFee Gas that needs to be compensated to relayer. Set to 0 if n/a
    /// @param _relayer Where to send gas compensation
    function _withdrawUSD(
        uint256 _shares,
        uint256 _maxSlippageFactor,
        address _account,
        uint256 _relayFee,
        address _relayer
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
