// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../../Stargate/IStargateReceiver.sol";

/// @title IControllerXChain
/// @notice Interface for cross chain controller
interface IControllerXChain is IStargateReceiver {
    /* Events */

    /* Structs */ 

    struct ControllerXChainInit {
        address layerZeroEndpoint;
        address stargateRouter;
        uint16 currentChain;
        uint256 sgPoolId;

        address router;
        address stablecoin;
        address tokenWETH;
        address stablecoinPriceFeed;
        address ethPriceFeed;

        address relayer;
    }

    struct SigComponents {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct XCPermitRequest {
        uint16 dstChain;
        uint256 dstPoolId;
        address remoteControllerXChain;
        address vault;
        address originWallet;
        address dstWallet;
        uint256 amount;
        uint256 slippageFactor;
        uint256 dstGasForCall;
        bytes data;
    }

    struct XCRequest {
        uint16 dstChain;
        uint256 dstPoolId;
        bytes remoteControllerXChain;
        address vault;
        uint256 amount;
        uint256 slippageFactor;
        address dstWallet;
        uint256 dstGasForCall;
        uint256 feeToReimburse;
        address refundAddress;
        bytes data;
    }

    struct StargateSwapParams {
        uint16 dstChainId;
        uint256 dstPoolId;
        uint256 amountUSD;
        uint256 minAmountLD;
        bytes dstControllerXChain;
        uint256 dstGasForCall;
        bytes payload;
    }

    /* State */

    // Infra

    /// @notice Gets Layer Zero cross chain endpoint address
    /// @return Address of endpoint
    function layerZeroEndpoint() external view returns (address);

    /// @notice Gets Stargate Router address
    /// @return Address of router
    function stargateRouter() external view returns (address);

    /// @notice Gets the LZ chain ID associated with this chain/contract
    /// @return Chain ID
    function currentChain() external view returns (uint16);

    /// @notice Gets the Stargate Pool ID associated with this chain/contract
    /// @return Pool ID
    function sgPoolId() external view returns (uint256);

    // Swaps

    /// @notice Gets Uni compatible router address (for swaps etc.)
    /// @return Address of router
    function router() external view returns (address);

    /// @notice Gets default stablecoin used on this chain/contract
    /// @return Address of stablecoin
    function stablecoin() external view returns (address);

    /// @notice Gets Uni compatible router address (for swaps etc.)
    /// @return Address of router
    function stablecoinPriceFeed() external view returns (AggregatorV3Interface);

    /* Deposits */ 

    /// @notice Encodes payload for deposit request
    /// @param _vault The vault address on the destination chain, to receive deposit
    /// @param _valueUSD Value of stablecoin to deposit on this chain, to be transferred to remote chain for deposit
    /// @param _slippageFactor Acceptable degree of slippage on any transaction (e.g. 9500 = 5%, 9900 = 1% etc.)
    /// @param _wallet Address on destination chain to send vault tokens to post-deposit
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.)
    function encodeDepositRequest(
        address _vault,
        uint256 _valueUSD,
        uint256 _slippageFactor,
        address _wallet,
        bytes memory _data
    ) external view returns (bytes memory);

    /// @notice Checks to see how much a cross chain deposit will cost
    /// @param _dstChain The LayerZero Chain ID
    /// @param _dstContract The remote chain's Zorro ControllerXChain contract
    /// @param _payload The byte encoded cross chain payload (use encodeXChainDepositPayload() above)
    /// @param _dstGasForCall The amount of gas to send on the destination chain for composable contract execution
    /// @return nativeFee Expected fee to pay for bridging/cross chain execution
    function getDepositQuote(
        uint16 _dstChain,
        bytes calldata _dstContract,
        bytes calldata _payload,
        uint256 _dstGasForCall
    ) external view returns (uint256 nativeFee);

    /// @notice Prepares and sends a cross chain deposit request. Takes care of necessary financial ops (transfer/locking USD)
    /// @dev Requires appropriate fee to be paid via msg.value and allowance of USD on this contract
    /// @param _dstChain LZ chain ID of the destination chain
    /// @param _dstPoolId The Stargate Pool ID to swap with on the remote chain
    /// @param _remoteControllerXChain Zorro ControllerXChain contract address on remote chain
    /// @param _vault Address of the vault on the remote chain to deposit into
    /// @param _dstWallet Address on destination chain to send vault tokens to post-deposit
    /// @param _amountUSD The amount of USD to deposit
    /// @param _slippageFactor Slippage tolerance for destination deposit function (9900 = 1%)
    /// @param _dstGasForCall Amount of gas to spend on the cross chain transaction
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.)
    function sendDepositRequest(
        uint16 _dstChain,
        uint256 _dstPoolId,
        bytes memory _remoteControllerXChain,
        address _vault,
        address _dstWallet,
        uint256 _amountUSD,
        uint256 _slippageFactor,
        uint256 _dstGasForCall,
        bytes memory _data
    ) external payable;

    /// @notice Dummy function for receiving deposit request
    /// @dev Necessary for type safety when matching function signatures. Actual logic is in internal _receiveDepositRequest() func.
    /// @param _vault Address of the vault on the remote chain to deposit into
    /// @param _valueUSD The amount of USD to deposit
    /// @param _slippageFactor Acceptable degree of slippage on any transaction (e.g. 9500 = 5%, 9900 = 1% etc.)
    /// @param _wallet The wallet on the current (receiving) chain that should receive the vault token upon deposit
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.)
    function receiveDepositRequest(
        address _vault,
        uint256 _valueUSD,
        uint256 _slippageFactor,
        address _wallet,
        bytes memory _data
    ) external;

    /* Withdrawals */

    /// @notice Encodes payload for making cross chan withdrawal
    /// @param _dstWallet The address on the remote chain to send bridged funds to
    function encodeWithdrawalRequest(
        address _dstWallet
    ) external view returns (bytes memory payload);

    /// @notice Gets quote for bridging withdrawn assets to another chain and sending to wallet
    /// @param _dstChain The LZ chain ID of the remote chain
    /// @param _dstContract The ControllerXChain contract on the remote chain
    /// @param _payload The payload to execute a function call on the remote chain
    /// @param _dstGasForCall Amount of gas to spend on the cross chain transaction
    /// @return nativeFee The fee in native coin to send to the router for the cross chain bridge
    function getWithdrawalQuote(
        uint16 _dstChain,
        bytes calldata _dstContract,
        bytes calldata _payload,
        uint256 _dstGasForCall
    ) external view returns (uint256 nativeFee);

    /// @notice Withdraws funds on chain and bridges to a destination wallet on a remote chain
    /// @dev Requires approval of asset token on the vault contract
    /// @param _dstChain The remote LZ chain ID to bridge funds to
    /// @param _dstPoolId The pool ID to swap tokens on the remote chain
    /// @param _remoteControllerXChain The ControllerXChain contract on the remote chain
    /// @param _vault Vault address on current chain to withdraw funds from
    /// @param _amount Number of tokens of the vault to withdraw
    /// @param _slippageFactor Acceptable degree of slippage on any transaction (e.g. 9500 = 5%, 9900 = 1% etc.)
    /// @param _dstWallet The address on the remote chain to send bridged funds to
    /// @param _dstGasForCall Amount of gas to spend on the cross chain transaction
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.)
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
    ) external payable;

    /// @notice Dummy function for receiving withdrawn funds on a remote chain
    /// @dev Necessary for type safety when matching function signatures. Actual logic is in internal _receiveWithdrawalRequest() func.
    /// @param _wallet Address for where to send withdrawn funds on-chain
    function receiveWithdrawalRequest(
        address _wallet
    ) external;

    /* Meta Transactions */

    /// @notice Performs gasless cross chain transactions (deposits/withdrawals/etc) using a signature
    /// @dev WARNING This function reimburses the relayer based on the gas sent with the tx. Therefore, please only sign using trusted 
    /// dApps or their relayers could collect excess gas reimbursement.
    /// @param _request XCPermitRequest struct containing the cross chain instructions
    /// @param _direction 0 for deposit and 1 for withdrawal
    /// @param _deadline Deadline for signature to be valid
    /// @param _sigComponents Elliptical sig params: v, r, s
    function requestWithPermit(
        XCPermitRequest calldata _request,
        uint8 _direction,
        uint256 _deadline,
        SigComponents calldata _sigComponents
    ) external payable;
}