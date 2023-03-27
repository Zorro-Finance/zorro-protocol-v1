// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../interfaces/TraderJoe/IBoostedMasterChefJoe.sol";

import "./_VaultAMMBase.sol";

/// @title TJ_AVAX_USDC
/// @notice Vault based on TraderJoe AVAX USDC V1 pool
contract TJ_AVAX_USDC is VaultAMMBase {
    function pendingRewards()
        public
        view
        override
        returns (uint256 pendingRewardsQty)
    {
        (pendingRewardsQty, , , ) = IBoostedMasterChefJoe(farmContract)
            .pendingTokens(pid, address(this));
    }

    function amountFarmed() public view override returns (uint256 farmed) {
        (farmed, , ) = IBoostedMasterChefJoe(farmContract).userInfo(
            pid,
            address(this)
        );
    }
}
