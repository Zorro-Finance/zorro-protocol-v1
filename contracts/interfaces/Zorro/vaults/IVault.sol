// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title IVault
/// @notice Interface for all vaults
interface IVault is IERC20Upgradeable {
    /* Events */

    /* Structs */

    struct VaultInit {
        address treasury;
        address router;
        uint256 entranceFeeFactor;
        uint256 withdrawFeeFactor;
    }

    /* Functions */

    // Key wallets/contracts

    /// @notice The Treasury (where fees get sent to)
    /// @return The address of the Treasury
    function treasury() external view returns (address);

    /// @notice The Uniswap compatible router
    /// @return The address of the router
    function router() external view returns (address);

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
    function defaultSlippageFactor() external view returns (uint256);

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
