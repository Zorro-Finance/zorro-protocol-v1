// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "../interfaces/Stargate/IStargateRouter.sol";

import "../interfaces/Zorro/controllers/IControllerXChain.sol";

import "../interfaces/Zorro/vaults/IVault.sol";

import "../libraries/LPUtility.sol";

import "../libraries/SafeSwap.sol";

import "../libraries/SafeSwapETH.sol";

import "hardhat/console.sol"; // TODO: Get rid of this


/// @title ControllerXChain
/// @notice Controls all cross chain operations
contract ControllerXChain is
    IControllerXChain,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    EIP712Upgradeable
{
    /* Constants */

    uint256 public constant BP_DENOMINATOR = 10000; // Basis point denominator
    bytes32 private constant _SEND_REQUEST_PERMIT_TYPEHASH =
        keccak256(
            "SendRequestPermit(XCPermitRequest request,uint8 direction,uint256 xcfee,uint256 nonce,uint256 deadline)XCPermitRequest(uint16 dstChain,uint256 dstPoolId,address remoteControllerXChain,address vault,address originWallet,address dstWallet,uint256 amount,uint256 slippageFactor,uint256 dstGasForCall,bytes data)"
        );
    bytes32 private constant _XC_PERMIT_REQUEST_TYPEHASH =
        keccak256(
            "XCPermitRequest(uint16 dstChain,uint256 dstPoolId,address remoteControllerXChain,address vault,address originWallet,address dstWallet,uint256 amount,uint256 slippageFactor,uint256 dstGasForCall,bytes data)"
        );

    /* Libraries */

    using SafeSwapUni for IUniswapV2Router02;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using LPUtility for IUniswapV2Router02;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /* Constructor */

    /// @notice Upgradeable constructor
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
        WETH = _initVal.tokenWETH;

        stablecoinPriceFeed = AggregatorV3Interface(
            _initVal.stablecoinPriceFeed
        );
        ethPriceFeed = AggregatorV3Interface(_initVal.ethPriceFeed);

        defaultSlippageFactor = 9900;

        // Transfer ownership
        _transferOwnership(_timelockOwner);

        // EIP712 init
        EIP712Upgradeable.__EIP712_init("ZXC Controller", "1");
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
    address public WETH;
    AggregatorV3Interface public stablecoinPriceFeed;
    AggregatorV3Interface public ethPriceFeed;
    uint256 public defaultSlippageFactor;

    // Meta Tx
    mapping(address => CountersUpgradeable.Counter) private _nonces;

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
    /// @param _weth Wrapped ETH token (equivalent native token (e.g. WAVAX, WBNB etc.))
    /// @param _stablecoinPriceFeed Price feed of stablecoin associated with this chain/endpoint on Stargate
    /// @param _stablecoinPriceFeed Price feed of ETH (equivalent native coin (e.g. AVAX, BNB))
    /// @param _defaultSlippageFactor Default slippage factor for swaps (1% = 9990)
    function setSwapParams(
        address _router,
        address _stablecoin,
        address _weth,
        address _stablecoinPriceFeed,
        address _ethPriceFeed,
        uint256 _defaultSlippageFactor
    ) external onlyOwner {
        router = _router;
        stablecoin = _stablecoin;
        WETH = _weth;
        stablecoinPriceFeed = AggregatorV3Interface(_stablecoinPriceFeed);
        ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);
        defaultSlippageFactor = _defaultSlippageFactor;
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
        address _wallet,
        bytes memory _data
    ) external pure returns (bytes memory payload) {
        // Calculate method signature
        bytes4 _sig = this.receiveDepositRequest.selector;

        // Calculate abi encoded bytes for input args
        bytes memory _inputs = abi.encode(
            _vault,
            _valueUSD,
            _slippageFactor,
            _wallet,
            _data
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
        uint256 _dstGasForCall,
        bytes memory _data
    ) external payable nonReentrant {
        // Require funds to be submitted with this message
        require(msg.value > 0, "No fees submitted");

        // Transfer USD into this contract
        IERC20Upgradeable(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            _amountUSD
        );

        // Call internal function
        _sendDepositRequest(
            XCRequest({
                dstChain: _dstChain,
                dstPoolId: _dstPoolId,
                remoteControllerXChain: _remoteControllerXChain,
                vault: _vault,
                dstWallet: _dstWallet,
                amount: _amountUSD,
                slippageFactor: _slippageFactor,
                dstGasForCall: _dstGasForCall,
                feeToReimburse: 0, // Not sent from a meta TX relayer so no reimbursement required
                refundAddress: _msgSender(),
                data: _data
            }),
            msg.value
        );
    }

    /// @dev Internal function for executing a cross chain deposit
    /// @param _req An XCRequest struct that describes the cross chain request parameters
    /// @param _xcFee Stargate native fee for XC bridging
    function _sendDepositRequest(XCRequest memory _req, uint256 _xcFee) internal {
        // Require funds to be submitted with this message
        require(_req.amount > 0, "No USD submitted");


        // Check balances
        uint256 _remainingUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );

        // Reimburse fees if necessary
        if (_req.feeToReimburse > 0) {
            // Convert USD to native ETH for gas + xc tx and refund relayer
            _recoupXCFeeFromUSD(_req.feeToReimburse, _req.refundAddress);

            // Update amount remaining
            _remainingUSD = IERC20Upgradeable(stablecoin).balanceOf(
                address(this)
            );
        }

        // Generate payload
        bytes memory _payload = this.encodeDepositRequest(
            _req.vault,
            _remainingUSD,
            _req.slippageFactor,
            _req.dstWallet,
            _req.data
        );

        // Call stargate to initiate bridge
        _callStargateSwapUSD(
            StargateSwapParams({
                dstChainId: _req.dstChain,
                dstPoolId: _req.dstPoolId,
                amountUSD: _remainingUSD,
                minAmountLD: (_remainingUSD * _req.slippageFactor) / BP_DENOMINATOR,
                dstControllerXChain: _req.remoteControllerXChain,
                dstGasForCall: _req.dstGasForCall,
                payload: _payload
            }),
            _xcFee,
            _req.refundAddress
        );
    }

    /// @inheritdoc	IControllerXChain
    function receiveDepositRequest(
        address _vault,
        uint256 _valueUSD,
        uint256 _slippageFactor,
        address _wallet,
        bytes memory _data
    ) public onlyRegEndpoint {
        // Revert to make sure this function never gets called
        require(false, "dummyfunc");

        // Satisfy compiler warnings (no execution)
        _receiveDepositRequest(_vault, _valueUSD, _slippageFactor, _wallet, _data);
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
        address _wallet,
        bytes memory _data
    ) internal {
        // Read vault stablecoin
        address _vaultStablecoin = IVault(_vault).stablecoin();

        // Approve spending
        IERC20Upgradeable(_vaultStablecoin).safeIncreaseAllowance(
            _vault,
            _valueUSD
        );

        // Deposit USD into vault
        IVault(_vault).depositUSD(_valueUSD, _slippageFactor, address(this), _wallet, _data);
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
        uint256 _amount,
        uint256 _slippageFactor,
        address _dstWallet,
        uint256 _dstGasForCall,
        bytes memory _data
    ) external payable nonReentrant {
        // Call internal function directly
        _sendWithdrawalRequest(
            XCRequest({
                dstChain: _dstChain,
                dstPoolId: _dstPoolId,
                remoteControllerXChain: _remoteControllerXChain,
                vault: _vault,
                amount: _amount,
                slippageFactor: _slippageFactor,
                dstWallet: _dstWallet,
                dstGasForCall: _dstGasForCall,
                feeToReimburse: 0, // No fee to reimburse
                refundAddress: _msgSender(),
                data: _data
            }),
            msg.sender
        );
    }

    /// @notice Internal function for sending withdrawal request
    /// @dev Allows for extra functionality for the permit flow
    /// @param _req A XCRequest struct to initiate the cross chain tx
    /// @param _source The source of the tokens to withdraw from (e.g. LP tokens)
    function _sendWithdrawalRequest(XCRequest memory _req, address _source) internal {
        // Perform withdraw USD operation
        IVault(_req.vault).withdrawUSD(_req.amount, _req.slippageFactor, _source, address(this), _req.data);

        // Get USD balance
        uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );
        require(_balUSD > 0, "no USD withdrawn");

        {   
            // Reimbursement logic (default to USD balance if no fees to reimburse)
            uint256 _remainingUSD = _balUSD;
            console.log("remainingUSD: ", _remainingUSD);

            // Reimburse fee (if applicable)
            if (_req.feeToReimburse > 0) {
                // Recoup from USD balance
                _recoupXCFeeFromUSD(_req.feeToReimburse, _req.refundAddress);

                // Update remaining USD for withdrawal
                _remainingUSD = IERC20Upgradeable(stablecoin).balanceOf(
                    address(this)
                );
            }

            // Get withdrawal payload
            bytes memory _payload = this.encodeWithdrawalRequest(
                _req.dstWallet
            );

            // Call Stargate Swap operation
            // Call stargate to initiate bridge

            _callStargateSwapUSD(
                StargateSwapParams({
                    dstChainId: _req.dstChain,
                    dstPoolId: _req.dstPoolId,
                    amountUSD: _remainingUSD,
                    minAmountLD: (_remainingUSD * _req.slippageFactor) /
                        BP_DENOMINATOR,
                    dstControllerXChain: _req.remoteControllerXChain,
                    dstGasForCall: _req.dstGasForCall,
                    payload: _payload
                }),
                msg.value,
                _msgSender()
            );
        }
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
            (address _vault, , uint256 _slippageFactor, address _wallet, bytes memory _data) = abi
                .decode(_paramsPayload, (address, uint256, uint256, address, bytes));

            // Determine stablecoin expected by vault
            address _vaultStablecoin = IVault(_vault).stablecoin();

            // Swap to default stablecoin for this vault (if applicable)
            if (_token != _vaultStablecoin) {
                // Calculate swap path
                address[] memory _swapPath = new address[](2);
                _swapPath[0] = _token;
                _swapPath[1] = _vaultStablecoin;

                // Perform swap
                IUniswapV2Router02(router).safeSwap(
                    _tokenBal,
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
                _wallet,
                _data
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
    /// @param _swapParams A StargateSwapParams struct describing the cross chain swap instructions
    /// @param _xcFee Total fee including Stargate fee and destination gas (usually expressed as msg.value)
    /// @param _refundAddress Where to send excess funds to (usually msg.sender)
    function _callStargateSwapUSD(
        StargateSwapParams memory _swapParams,
        uint256 _xcFee,
        address _refundAddress
    ) internal {
        // Approve spending by Stargate
        IERC20Upgradeable(stablecoin).safeIncreaseAllowance(
            stargateRouter,
            _swapParams.amountUSD
        );

        // Specify gas for cross chain message
        IStargateRouter.lzTxObj memory _lzTxObj;
        _lzTxObj.dstGasForCall = _swapParams.dstGasForCall;

        // Swap call
        IStargateRouter(stargateRouter).swap{value: _xcFee}(
            _swapParams.dstChainId,
            sgPoolId,
            _swapParams.dstPoolId,
            payable(_refundAddress),
            _swapParams.amountUSD,
            _swapParams.minAmountLD,
            _lzTxObj,
            _swapParams.dstControllerXChain,
            _swapParams.payload
        );
    }

    /* Meta Transactions */

    /// @inheritdoc	IControllerXChain
    function requestWithPermit(
        XCPermitRequest calldata _request,
        uint8 _direction,
        uint256 _deadline,
        SigComponents calldata _sigComponents
    ) external payable nonReentrant {
        // Init
        uint256 _startGas = gasleft(); // To track gas reimbursement.

        // Check deadline
        require(block.timestamp <= _deadline, "ZorroXC: expired deadline");

        // Check if signer matches sender
        require(
            _verifySignature(_request, _direction, _deadline, _sigComponents),
            "ZorroXC: invalid signature"
        );

        // Allow transaction through
        if (_direction == 0) {
            // Deposit

            // Safe transfer USD IN
            IERC20Upgradeable(stablecoin).safeTransferFrom(
                _request.originWallet,
                address(this),
                _request.amount
            );

            // Check balances
            uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
                address(this)
            );

            console.log("msg.value, startGas, balUSD: ", msg.value, _startGas, _balUSD);

            // Make XC deposit request
            _sendDepositRequest(
                XCRequest({
                    dstChain: _request.dstChain,
                    dstPoolId: _request.dstPoolId,
                    remoteControllerXChain: abi.encodePacked(
                        _request.remoteControllerXChain
                    ),
                    vault: _request.vault,
                    dstWallet: _request.dstWallet,
                    amount: _balUSD,
                    slippageFactor: _request.slippageFactor,
                    dstGasForCall: _request.dstGasForCall,
                    feeToReimburse: msg.value + _startGas * tx.gasprice,
                    refundAddress: _msgSender(), // Set refund address to the relayer
                    data: _request.data
                }),
                msg.value
            );
        } else if (_direction == 1) {
            // Withdraw

            // Make XC withdrawal request
            _sendWithdrawalRequest(
                XCRequest({
                    dstChain: _request.dstChain,
                    dstPoolId: _request.dstPoolId,
                    remoteControllerXChain: abi.encodePacked(
                        _request.remoteControllerXChain
                    ),
                    vault: _request.vault,
                    amount: _request.amount,
                    slippageFactor: _request.slippageFactor,
                    dstWallet: _request.dstWallet,
                    dstGasForCall: _request.dstGasForCall,
                    feeToReimburse: msg.value + _startGas * tx.gasprice,
                    refundAddress: _msgSender(),
                    data: _request.data
                }),
                _request.originWallet
            );
        } else {
            revert("ZorroXC: invalid dir");
        }
    }

    // TODO docstring
    function _verifySignature(
        XCPermitRequest calldata _request,
        uint8 _direction,
        uint256 _deadline,
        SigComponents calldata _sigComponents
    ) internal returns (bool isValid) {
        // Encode bytes of all request parameters
        // NOTE: Must be done in chunks to prevent "stack too deep" compiler errors
        bytes memory encodedPermitRequest = abi.encode(
            _XC_PERMIT_REQUEST_TYPEHASH, 
            _request.dstChain,
            _request.dstPoolId,
            _request.remoteControllerXChain
        );

        {
            encodedPermitRequest = bytes.concat(
                encodedPermitRequest,
                abi.encode(
                    _request.vault,
                    _request.originWallet,
                    _request.dstWallet,
                    _request.amount
                )
            );
        }

        {
            encodedPermitRequest = bytes.concat(
                encodedPermitRequest,
                abi.encode(
                    _request.slippageFactor,
                    _request.dstGasForCall,
                    keccak256(_request.data)
                )
            );
        }

        // Calculate hash of typed data
        bytes32 _structHash = keccak256(
            abi.encode(
                _SEND_REQUEST_PERMIT_TYPEHASH,
                keccak256(encodedPermitRequest),
                _direction,
                msg.value,
                _useNonce(_request.originWallet),
                _deadline
            )
        );
        bytes32 _hash = _hashTypedDataV4(_structHash);

        // Extract signer from signature
        address _signer = ECDSAUpgradeable.recover(
            _hash,
            _sigComponents.v,
            _sigComponents.r,
            _sigComponents.s
        );

        // Check if signature is valid
        isValid = _signer == _request.originWallet;
    }

    /// @notice Swaps USD to ETH to compensate relayer for XC fee spent
    /// @param _fee The amount of ETH used for the XC fee
    /// @param _relayer The address of the relayer to compensate
    function _recoupXCFeeFromUSD(uint256 _fee, address _relayer) internal {
        // Prep swap path
        address[] memory _swapPath = new address[](2);
        _swapPath[0] = stablecoin;
        _swapPath[1] = WETH;

        console.log("swapPath 0, 1: ", stablecoin, WETH);
        console.log("Fee to be collected, relayer: ", _fee, _relayer);

        // Swap USD to ETH to the relayer
        SafeSwapUniETH.safeSwapToETH(
            router,
            _fee,
            _swapPath,
            stablecoinPriceFeed,
            ethPriceFeed,
            defaultSlippageFactor,
            _relayer
        );
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

    /// @notice Public func for returning nonce for a signer
    /// @dev Every successful call to a permit function increments the signer's nonce to prevent replays.
    /// @param _owner The signer of the nonce
    /// @return current Current nonce value
    function nonces(
        address _owner
    ) public view virtual returns (uint256 current) {
        current = _nonces[_owner].current();
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

    /* Proxy implementations */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
