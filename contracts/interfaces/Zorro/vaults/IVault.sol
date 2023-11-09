// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title IVault
/// @notice Interface for all vaults
interface IVault {
    /* Events */

    event DepositUSD(
        address indexed _pool,
        uint256 indexed _amountUSD,
        uint256 _maxSlippageFactor
    );

    event WithdrawUSD(
        address indexed _pool,
        uint256 indexed _amountUSD,
        uint256 _maxSlippageFactor
    );

    event ReinvestEarnings(
        uint256 indexed _amtReinvested,
        address indexed _assetToken
    );

    /* Structs */

    struct VaultPriceFeeds {
        address eth;
        address stablecoin;
    }

    struct VaultInit {
        VaultPriceFeeds priceFeeds;
        address treasury;
        address router;
        address stablecoin;
        address tokenWETH;
        uint256 entranceFeeFactor;
        uint256 withdrawFeeFactor;
    }

    struct SigComponents {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /* Functions */

    // Key wallets/contracts

    /// @notice The Treasury (where fees get sent to)
    /// @return The address of the Treasury
    function treasury() external view returns (address);

    /// @notice The Uniswap compatible router
    /// @return The address of the router
    function router() external view returns (address);

    /// @notice The default stablecoin (e.g. USDC, BUSD)
    /// @return The address of the stablecoin
    function stablecoin() external view returns (address);

    // Accounting & Fees

    /// @notice Entrance fee - goes to treasury
    /// @dev 9990 results in a 0.1% deposit fee (1 - 9990/10000)
    /// @return The entrance fee factor
    function entranceFeeFactor() external view returns (uint256);

    /// @notice Withdrawal fee - goes to treasury
    /// @return The withdrawal fee factor
    function withdrawFeeFactor() external view returns (uint256);

    /// @notice Default value for slippage if not overridden by a specific func
    /// @dev 9900 results in 1% slippage (1 - 9900/10000)
    /// @return The slippage factor numerator
    function defaultSlippageFactor() external view returns (uint256);

    // Governor

    /// @notice Governor address for non timelock admin operations
    /// @return The address of the governor
    function gov() external view returns (address);

    // Cash flow operations

    /// @notice Converts USD* to main asset and deposits it
    /// @param _amountUSD The amount of USD to deposit
    /// @param _maxSlippageFactor Max amount of slippage tolerated per UniswapV2 operation (9900 = 1%)
    /// @param _source Where the USD should be transfered from (requires approval)
    /// @param _recipient Where the received tokens should be sent to
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.)
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _source,
        address _recipient,
        bytes memory _data
    ) external;

    /// @notice Withdraws main asset, converts to USD*, and sends back to sender
    /// @param _amount The number of units of the main asset to withdraw (e.g. LP tokens) (Units will vary so see child contract)
    /// @param _maxSlippageFactor Max amount of slippage tolerated per UniswapV2 operation (9900 = 1%)
    /// @param _source Where the investment tokens (e.g. LP tokens, shares, etc.) should be transfered from (requires approval)
    /// @param _recipient Where the withdrawn USD should be sent to
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.)
    function withdrawUSD(
        uint256 _amount, 
        uint256 _maxSlippageFactor,
        address _source,
        address _recipient,
        bytes memory _data
    ) external;

    /// @notice Performs gasless deposits/withdrawals from/to USD using a signature
    /// @dev WARNING This function reimburses the relayer based on the gas sent with the tx. Therefore, please only sign using trusted 
    /// dApps or their relayers could collect excess gas reimbursement.
    /// @param _account Account that is signing this transaction (source of and recipient of tokens)
    /// @param _amount The amount of USD (for deposits) or tokens (for withdrawals)
    /// @param _maxSlippageFactor Max amount of slippage tolerated per UniswapV2 operation (9900 = 1%)
    /// @param _direction 0 for deposit and 1 for withdrawal
    /// @param _deadline Deadline for signature to be valid
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.)
    /// @param _sigComponents Elliptical sig params
    function transactUSDWithPermit(
        address _account,
        uint256 _amount,
        uint256 _maxSlippageFactor,
        uint8 _direction,
        uint256 _deadline,
        bytes memory _data,
        SigComponents calldata _sigComponents
    ) external;

    // Token operations

    /// @notice Shows swap paths for a given start and end token
    /// @param _startToken The origin token to swap from
    /// @param _endToken The destination token to swap to
    /// @param _index The index of the swap path to retrieve the token for
    /// @return The token address
    function swapPaths(
        address _startToken,
        address _endToken,
        uint256 _index
    ) external view returns (address);

    /// @notice Shows the length of the swap path for a given start and end token
    /// @param _startToken The origin token to swap from
    /// @param _endToken The destination token to swap to
    /// @return The length of the swap paths
    function swapPathLength(
        address _startToken,
        address _endToken
    ) external view returns (uint16);

    /// @notice Returns a Chainlink-compatible price feed for a provided token address, if it exists
    /// @param _token The token to return a price feed for
    /// @return An AggregatorV3 price feed
    function priceFeeds(
        address _token
    ) external view returns (AggregatorV3Interface);

    // Maintenance

    /// @notice Pauses key contract operations
    function pause() external;

    /// @notice Resumes key contract operations
    function unpause() external;
}
