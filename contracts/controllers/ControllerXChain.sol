// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/Stargate/IStargateRouter.sol";

import "../interfaces/Zorro/controllers/IControllerXChain.sol";

import "../interfaces/Zorro/vaults/IVault.sol";

import "../libraries/LPUtility.sol";

import "../libraries/SafeSwap.sol";

/// @title ControllerXChain
/// @notice Controls all cross chain operations
contract ControllerXChain is
    IControllerXChain,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /* Constants */

    uint256 public constant BP_DENOMINATOR = 10000; // Basis point denominator

    /* Libraries */

    using SafeSwapUni for IAMMRouter02;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using LPUtility for IAMMRouter02;

    /* Constructor */

    /// @notice Constructor
    /// @param _initVal A ControllerXChainInit struct
    /// @param _timelockOwner The designated owner of this contract (usually a timelock)
    function initialize(
        ControllerXChainInit memory _initVal,
        address _timelockOwner
    ) public initializer {
        // Set state variables
        layerZeroEndpoint = _initVal.layerZeroEndpoint;
        stargateRouter = _initVal.stargateRouter;
        currentChain = _initVal.currentChain;
        sgPoolId = _initVal.sgPoolId;

        router = _initVal.router;
        stablecoin = _initVal.stablecoin;
        stablecoinPriceFeed = AggregatorV3Interface(
            _initVal.stablecoinPriceFeed
        );

        // Transfer ownership
        _transferOwnership(_timelockOwner);
    }

    /* State */

    // Infra
    address public layerZeroEndpoint;
    address public stargateRouter;
    uint16 public currentChain;
    uint256 public sgPoolId;

    // Swaps
    address public router;
    address public stablecoin;
    AggregatorV3Interface public stablecoinPriceFeed;

    /* Setters */

    /// @notice Sets key cross chain contract addresses
    /// @param _lzEndpoint LayerZero endpoint address
    /// @param _sgRouter Stargate Router address
    /// @param _chain LZ chain ID
    /// @param _sgPoolId Stargate Pool ID
    function setKeyXChainParams(
        address _lzEndpoint,
        address _sgRouter,
        uint16 _chain,
        uint256 _sgPoolId
    ) external onlyOwner {
        layerZeroEndpoint = _lzEndpoint;
        stargateRouter = _sgRouter;
        currentChain = _chain;
        sgPoolId = _sgPoolId;
    }

    /// @notice Sets swap parameters
    /// @param _router Router address
    /// @param _stablecoin Stablecoin address
    /// @param _stablecoinPriceFeed Price feed of stablecoin associated with this chain/endpoint on Stargate
    function setSwapParams(
        address _router,
        address _stablecoin,
        address _stablecoinPriceFeed
    ) external onlyOwner {
        router = _router;
        stablecoin = _stablecoin;
        stablecoinPriceFeed = AggregatorV3Interface(_stablecoinPriceFeed);
    }

    /* Modifiers */

    /// @notice Ensures cross chain request is coming only from a LZ endpoint or STG router address
    modifier onlyRegEndpoint() {
        require(
            msg.sender == layerZeroEndpoint || msg.sender == stargateRouter,
            "Unrecog xchain sender"
        );
        _;
    }

    /* Deposits */

    /// @inheritdoc	IControllerXChain
    function encodeDepositRequest(
        address _vault,
        uint256 _valueUSD,
        uint256 _slippageFactor,
        address _wallet
    ) external pure returns (bytes memory payload) {
        // Calculate method signature
        bytes4 _sig = this.receiveDepositRequest.selector;

        // Calculate abi encoded bytes for input args
        bytes memory _inputs = abi.encode(
            _vault,
            _valueUSD,
            _slippageFactor,
            _wallet
        );

        // Concatenate bytes of signature and inputs
        payload = bytes.concat(_sig, _inputs);

        require(payload.length > 0, "Invalid xchain payload");
    }

    /// @inheritdoc	IControllerXChain
    function getDepositQuote(
        uint16 _dstChain,
        bytes calldata _dstContract,
        bytes calldata _payload,
        uint256 _dstGasForCall
    ) external view returns (uint256 nativeFee) {
        // Init empty LZ object
        IStargateRouter.lzTxObj memory _lzTxParams;

        // Tack on xchain contract gas fee
        _lzTxParams.dstGasForCall = _dstGasForCall;

        // Calculate native gas fee and ZRO token fee (Layer Zero token)
        (nativeFee, ) = IStargateRouter(stargateRouter).quoteLayerZeroFee(
            _dstChain,
            1,
            _dstContract,
            _payload,
            _lzTxParams
        );
    }

    /// @inheritdoc	IControllerXChain
    function sendDepositRequest(
        uint16 _dstChain,
        uint256 _dstPoolId,
        bytes calldata _remoteControllerXChain,
        address _vault,
        address _dstWallet,
        uint256 _amountUSD,
        uint256 _slippageFactor,
        uint256 _dstGasForCall
    ) external payable nonReentrant {
        // Require funds to be submitted with this message
        require(msg.value > 0, "No fees submitted");
        require(_amountUSD > 0, "No USD submitted");

        // Transfer USD into this contract
        IERC20Upgradeable(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            _amountUSD
        );

        // Check balances
        uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );

        // Generate payload
        bytes memory _payload = this.encodeDepositRequest(
            _vault,
            _balUSD,
            _slippageFactor,
            _dstWallet
        );

        // Call stargate to initiate bridge
        _callStargateSwapUSD(
            _dstChain,
            _dstPoolId,
            _balUSD,
            _balUSD * _slippageFactor / BP_DENOMINATOR,
            _remoteControllerXChain,
            _dstGasForCall,
            _payload
        );
    }

    /// @inheritdoc	IControllerXChain
    function receiveDepositRequest(
        address _vault,
        uint256 _valueUSD,
        uint256 _slippageFactor,
        address _wallet
    ) public onlyRegEndpoint {
        // Revert to make sure this function never gets called
        require(false, "dummyfunc");

        // Satisfy compiler warnings (no execution)
        _receiveDepositRequest(_vault, _valueUSD, _slippageFactor, _wallet);
    }

    /// @notice Internal function for receiving and processing deposit request
    /// @param _vault Address of the vault on the remote chain to deposit into
    /// @param _valueUSD The amount of USD to deposit
    /// @param _slippageFactor Acceptable degree of slippage on any transaction (e.g. 9500 = 5%, 9900 = 1% etc.)
    /// @param _wallet The wallet on the current (receiving) chain that should receive the vault token upon deposit
    function _receiveDepositRequest(
        address _vault,
        uint256 _valueUSD,
        uint256 _slippageFactor,
        address _wallet
    ) internal {
        // Read vault stablecoin
        address _vaultStablecoin = IVault(_vault).stablecoin();

        // Approve spending
        IERC20Upgradeable(_vaultStablecoin).safeIncreaseAllowance(
            _vault,
            _valueUSD
        );

        // Deposit USD into vault
        IVault(_vault).depositUSD(_valueUSD, _slippageFactor);

        // Get quantity of received shares
        uint256 _receivedShares = IERC20Upgradeable(_vault).balanceOf(
            address(this)
        );

        // Send resulting shares to specified wallet
        IERC20Upgradeable(_vault).safeTransfer(_wallet, _receivedShares);
    }

    /* Withdrawals */

    /// @inheritdoc	IControllerXChain
    function encodeWithdrawalRequest(
        address _dstWallet
    ) external pure returns (bytes memory payload) {
        // Calculate method signature
        bytes4 _sig = this.receiveWithdrawalRequest.selector;

        // Calculate abi encoded bytes for input args
        bytes memory _inputs = abi.encode(_dstWallet);

        // Concatenate bytes of signature and inputs
        payload = bytes.concat(_sig, _inputs);

        require(payload.length > 0, "Invalid xchain payload");
    }

    /// @inheritdoc	IControllerXChain
    function getWithdrawalQuote(
        uint16 _dstChain,
        bytes calldata _dstContract,
        bytes calldata _payload,
        uint256 _dstGasForCall
    ) external view returns (uint256 nativeFee) {
        // Init empty LZ object
        IStargateRouter.lzTxObj memory _lzTxParams;

        // Tack on xchain contract gas fee
        _lzTxParams.dstGasForCall = _dstGasForCall;

        // Calculate native gas fee
        (nativeFee, ) = IStargateRouter(stargateRouter).quoteLayerZeroFee(
            _dstChain,
            1,
            _dstContract,
            _payload,
            _lzTxParams
        );
    }

    /// @inheritdoc	IControllerXChain
    function sendWithdrawalRequest(
        uint16 _dstChain,
        uint256 _dstPoolId,
        bytes calldata _remoteControllerXChain,
        address _vault,
        uint256 _shares,
        uint256 _slippageFactor,
        address _dstWallet,
        uint256 _dstGasForCall
    ) external payable nonReentrant {
        // Safe transfer IN the vault tokens
        IERC20Upgradeable(_vault).safeTransferFrom(
            _msgSender(),
            address(this),
            _shares
        );

        // Approve spending
        IERC20Upgradeable(_vault).safeIncreaseAllowance(_vault, _shares);

        // Perform withdraw USD operation
        IVault(_vault).withdrawUSD(_shares, _slippageFactor);

        // Get USD balance
        uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );
        require(_balUSD > 0, "no USD withdrawn");

        // Get withdrawal payload
        bytes memory _payload = this.encodeWithdrawalRequest(_dstWallet);

        // Call Stargate Swap operation
        // Call stargate to initiate bridge
        _callStargateSwapUSD(
            _dstChain,
            _dstPoolId,
            _balUSD,
            _balUSD * _slippageFactor / BP_DENOMINATOR,
            _remoteControllerXChain,
            _dstGasForCall,
            _payload
        );
    }

    /// @inheritdoc	IControllerXChain
    function receiveWithdrawalRequest(address _wallet) public onlyRegEndpoint {
        // Revert to make sure this function never gets called
        require(false, "dummyfunc");

        // Satisfy compiler warnings (no execution)
        _receiveWithdrawalRequest(_wallet, address(0));
    }

    /// @notice Internal function for receiving and processing withdrawal request
    /// @param _wallet The address to send the tokens from the cross chain swap to
    /// @param _token The address of the token received in the cross chain swap
    function _receiveWithdrawalRequest(
        address _wallet,
        address _token
    ) internal {
        // Get current balance
        uint256 _balToken = IERC20Upgradeable(_token).balanceOf(address(this));

        // Send tokens to wallet
        IERC20Upgradeable(_token).safeTransfer(_wallet, _balToken);
    }

    /* Receive XChain */

    /// @inheritdoc	IStargateReceiver
    function sgReceive(
        uint16 _chainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        address _token,
        uint256 amountLD,
        bytes memory payload
    ) external onlyRegEndpoint nonReentrant {
        // Prechecks / authorization
        require(_chainId >= 0);
        require(_srcAddress.length > 0);
        require(_nonce >= 0);

        // Amounts
        uint256 _tokenBal = IERC20Upgradeable(_token).balanceOf(address(this));
        require(amountLD <= _tokenBal, "amountLD exceeds bal");

        // Determine function based on signature
        // Get func signature
        bytes4 _funcSig = bytes4(payload);
        // Get params payload only
        bytes memory _paramsPayload = this.extractParamsPayload(payload);

        // Match to appropriate func
        if (this.receiveDepositRequest.selector == _funcSig) {
            // Decode params
            (address _vault, , uint256 _slippageFactor, address _wallet) = abi
                .decode(_paramsPayload, (address, uint256, uint256, address));

            // Determine stablecoin expected by vault
            address _vaultStablecoin = IVault(_vault).stablecoin();

            // Swap to default stablecoin for this vault (if applicable)
            if (_token != _vaultStablecoin) {
                // Calculate swap path
                address[] memory _swapPath = new address[](2);
                _swapPath[0] = _token;
                _swapPath[1] = _vaultStablecoin;

                // Perform swap
                IAMMRouter02(router).safeSwap(
                    _tokenBal,
                    _token,
                    _vaultStablecoin,
                    _swapPath,
                    stablecoinPriceFeed,
                    IVault(_vault).priceFeeds(_vaultStablecoin),
                    _slippageFactor,
                    address(this)
                );
            }

            // Determine bal of stablecoin for vault
            uint256 _balVaultStablecoin = IERC20Upgradeable(_vaultStablecoin)
                .balanceOf(address(this));

            // Call receiving function for cross chain deposits
            // Replace _valueUSD to account for any slippage during bridging
            _receiveDepositRequest(
                _vault,
                _balVaultStablecoin,
                _slippageFactor,
                _wallet
            );
        } else if (this.receiveWithdrawalRequest.selector == _funcSig) {
            // Decode params from payload
            address _wallet = abi.decode(_paramsPayload, (address));

            // Forward request to distribution function
            _receiveWithdrawalRequest(_wallet, _token);
        } else {
            revert("Unrecognized func");
        }
    }

    /// @notice Internal function for making swap calls to Stargate
    /// @dev IMPORTANT: This function assumes that the input token is the same as the `stablecoin` value on this contract
    /// @param _dstChainId The destination LZ chain Id
    /// @param _dstPoolId The Stargate pool on the destination chain to swap with
    /// @param _amountUSD The amount of input token (USD) on this chain to swap
    /// @param _minAmountLD The minimal amount of output token expected on the destination chain
    /// @param _dstControllerXChain Zorro cross chain controller address on the destination chain
    /// @param _dstGasForCall How much gas to reserve for the remote chain function execution
    /// @param _payload Payload for function execution on the remote chain
    function _callStargateSwapUSD(
        uint16 _dstChainId,
        uint256 _dstPoolId,
        uint256 _amountUSD,
        uint256 _minAmountLD,
        bytes calldata _dstControllerXChain,
        uint256 _dstGasForCall,
        bytes memory _payload
    ) internal {
        // Approve spending by Stargate
        IERC20Upgradeable(stablecoin).safeIncreaseAllowance(
            stargateRouter,
            _amountUSD
        );

        // Specify gas for cross chain message
        IStargateRouter.lzTxObj memory _lzTxObj;
        _lzTxObj.dstGasForCall = _dstGasForCall;

        // Swap call
        IStargateRouter(stargateRouter).swap{value: msg.value}(
            _dstChainId,
            sgPoolId,
            _dstPoolId,
            payable(_msgSender()),
            _amountUSD,
            _minAmountLD,
            _lzTxObj,
            _dstControllerXChain,
            _payload
        );
    }

    /* Utilities */

    /// @notice Removes function signature from ABI encoded payload
    /// @param _payloadWithSig ABI encoded payload with function selector
    /// @return paramsPayload Payload with params only
    function extractParamsPayload(
        bytes calldata _payloadWithSig
    ) public pure returns (bytes memory paramsPayload) {
        paramsPayload = _payloadWithSig[4:];
    }

    /// @notice For owner to recover ERC20 tokens on this contract if stuck
    /// @dev Does not permit usage for the Zorro token
    /// @param _token ERC20 token address
    /// @param _amount token quantity
    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount
    ) public onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(_msgSender(), _amount);
    }
}
