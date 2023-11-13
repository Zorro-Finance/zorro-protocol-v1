// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import "../interfaces/Zorro/vaults/IVault.sol";

import "../libraries/PriceFeed.sol";

import "../libraries/SafeSwap.sol";

import "../libraries/SafeSwapETH.sol";

/// @title VaultBase
/// @notice Base contract for all vaults
abstract contract VaultBase is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IVault,
    UUPSUpgradeable,
    EIP712Upgradeable
{
    /* Constants */

    uint256 public constant BP_DENOMINATOR = 10000; // Basis point denominator
    bytes32 private constant _PERMIT_TRANSACT_USD_TYPEHASH =
        keccak256(
            "TransactUSDPermit(address account,uint256 amount,uint256 maxMarketMovement,uint8 direction,uint256 nonce,uint256 deadline,bytes data)"
        );

    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using PriceFeed for AggregatorV3Interface;
    using SafeSwapUni for IUniswapV2Router02;
    using CountersUpgradeable for CountersUpgradeable.Counter;

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

        // Set price feeds
        _setPriceFeed(_initVal.tokenWETH, _initVal.priceFeeds.eth);
        _setPriceFeed(_initVal.stablecoin, _initVal.priceFeeds.stablecoin);

        // Transfer ownership to the timelock controller
        _transferOwnership(_timelockOwner);

        // Governor
        gov = _gov;

        // EIP712 init
        _initEIP712();
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
    mapping(address => AggregatorV3Interface) public priceFeeds; // Price feeds. Mapping: token address => price feed address (AggregatorV3Interface implementation)

    // Gasless
    address public relayer;
    mapping(address => CountersUpgradeable.Counter) private _nonces;

    /* Modifiers */

    modifier onlyAllowGov() {
        require(_msgSender() == gov, "!gov");
        _;
    }

    modifier onlyAllowRelayer() {
        require(_msgSender() == relayer, "!relayer");
        _;
    }

    /* Setters */

    /// @notice Sets the only permitted address that can relay permit transactions (e.g. transactUSDWithPermit)
    /// @param _relayer The address of the relayer
    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
    }

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
        bytes memory _data,
        SigComponents calldata _sigComponents
    ) external whenNotPaused onlyAllowRelayer {
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
                _deadline,
                keccak256(_data)
            )
        );
        bytes32 _hash = _hashTypedDataV4(_structHash);

        // Extract signer from signature
        address _signer = ECDSAUpgradeable.recover(_hash, _sigComponents.v, _sigComponents.r, _sigComponents.s);

        // Check if signer matches sender
        require(_signer == _account, "ZorroVault: invalid signature");

        // Allow transaction through
        if (_direction == 0) {
            // Deposit
            _depositUSD(
                _amount,
                _maxSlippageFactor,
                _account,
                _account,
                _startGas * tx.gasprice,
                _msgSender(),
                _data
            );
        } else if (_direction == 1) {
            // Withdraw
            _withdrawUSD(
                _amount,
                _maxSlippageFactor,
                _account,
                _account,
                _startGas * tx.gasprice,
                _msgSender(),
                _data
            );
        } else {
            revert("ZorroVault: invalid dir");
        }
    }

    /// @notice Public func for returning nonce for a signer
    /// @dev Every successful call to a permit function increments the signer's nonce to prevent replays.
    /// @param _owner The signer of the nonce
    /// @return current Current nonce value
    function nonces(
        address _owner
    ) public view virtual returns (uint256 current) {
        current = _nonces[_owner].current();
    }

    /// @notice "Consume a nonce": return the current value and increment.
    /// @param _owner Address of the signer
    /// @return current Current nonce value
    function _useNonce(
        address _owner
    ) internal virtual returns (uint256 current) {
        CountersUpgradeable.Counter storage _nonce = _nonces[_owner];
        current = _nonce.current();
        _nonce.increment();
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

    /* Meta Transactions */

    /// @notice Internal function for initializing the EIP712 constructor
    /// @dev Domain hash veries by contract so this is marked as abstract
    function _initEIP712() internal virtual;

    /* Utilities */

    /// @notice Internal utility for reversing the swap path (e.g. token0 -> stablecoin to stablecoin -> token0)
    /// @param _path The array of addresses representing the swap path
    /// @return newPath The swap path in the opposite direction
    function _reverseSwapPath(address[] memory _path) internal pure returns (address[] memory newPath) {
        uint256 _pathLength = _path.length;
        address[] memory _newPath = new address[](_pathLength);

        for (uint8 i = 0; i < _pathLength; i++) {
            _newPath[i] = _path[_pathLength - 1 - i];
        }

        return _newPath;
    }
}
