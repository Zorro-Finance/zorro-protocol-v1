// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../interfaces/TraderJoe/IBoostedMasterChefJoe.sol";

import "./_VaultAMMBase.sol";

/// @title TraderJoeAMMV1
/// @notice Vault based on TraderJoe V1 pool
contract TraderJoeAMMV1 is VaultAMMBase {
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
