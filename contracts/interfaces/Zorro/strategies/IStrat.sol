// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/// @title IStrat
/// @notice Interface for all strategies
interface IStrat {
    /* Structs */

    struct StratInit {
        address treasury;
        address stablecoin;
        uint256 entranceFeeFactor;
        uint256 withdrawFeeFactor;
    }

    /* Events */

    event DepositUSD(uint256 _amountUSD);

    event WithdrawUSD(uint256 _amountUSD);

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
    /// @param _recipient Where the received tokens should be sent to
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.) (See child contract)
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) external;

    /// @notice Withdraws main asset, converts to USD*, and sends back to sender
    /// @param _amount The number of units of the main asset to withdraw (e.g. LP tokens) (Units will vary so see child contract)
    /// @param _maxSlippageFactor Max amount of slippage tolerated per UniswapV2 operation (9900 = 1%)
    /// @param _recipient Where the withdrawn USD should be sent to
    /// @param _data Data that encodes the pool specific params (e.g. tokens, LP assets, etc.) (See child contract)
    function withdrawUSD(
        uint256 _amount, 
        uint256 _maxSlippageFactor,
        address _recipient,
        bytes memory _data
    ) external;

    // Maintenance

    /// @notice Pauses key contract operations
    function pause() external;

    /// @notice Resumes key contract operations
    function unpause() external;
}
