// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IStrat
/// @notice Interface for all strategies
interface IStrat {
    /* Structs */

    struct StratInit {
        address treasury;
        address stablecoin;
        uint256 defaultFeeFactor;
    }

    /* Functions */

    // Key wallets/contracts

    /// @notice The Treasury (where fees get sent to)
    /// @return The address of the Treasury
    function treasury() external view returns (address);

    /// @notice The default stablecoin (e.g. USDC, BUSD)
    /// @return The address of the stablecoin
    function stablecoin() external view returns (address);

    // Accounting & Fees

    /// @notice Default fee - goes to treasury
    /// @dev 9990 results in a 0.1% fee (1 - 9990/10000)
    /// @return The default fee factor
    function defaultFeeFactor() external view returns (uint256);

    // Governor

    /// @notice Governor address for non timelock admin operations
    /// @return The address of the governor
    function gov() external view returns (address);

    // Maintenance

    /// @notice Pauses key contract operations
    function pause() external;

    /// @notice Resumes key contract operations
    function unpause() external;
}
