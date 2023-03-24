// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./_VaultBase.sol";

import "../interfaces/Zorro/vaults/IVaultAMM.sol";

import "../interfaces/Uniswap/IAMMFarm.sol";

/// @title VaultAMMBase
/// @notice Abstract base contract for standard AMM based vaults
abstract contract VaultAMMBase is VaultBase, IVaultAMM {
    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _asset The main asset for the underlying pool
    /// @param _stablecoin The default stablecoin to use for USD deposits/withdrawals
    function initialize(
        address _asset,
        address _stablecoin
    ) public override initializer {
        asset = _asset;
        stablecoin = _stablecoin;

        // TODO: Initializer for ERC20 (token, symbol, decimals etc.)

        // TODO: All the other init vals.
    }

    /* State */

    // Accounting
    uint256 public assetLockedTotal;

    // Key tokens, contracts, and config
    address public asset;
    address public stablecoin;
    address public token0;
    address public token1;
    address public farmContract;
    address public farmToken;
    bool public isFarmable;
    uint256 public pid;
    address public pool;

    /* Setters */

    // TODO: Docstrings for ALL setters below
    function setTokens(
        address _asset,
        address _stablecoin,
        address _token0,
        address _token1,
        address _pool
    ) external onlyOwner {
        asset = _asset;
        stablecoin = _stablecoin;
        token0 = _token0;
        token1 = _token1;
        pool = _pool;
    }

    function setFarmParams(
        bool _isFarmable,
        address _farmContract,
        address _farmToken,
        uint256 _pid
    ) external onlyOwner {
        isFarmable = _isFarmable;
        farmContract = _farmContract;
        farmToken = _farmToken;
        pid = _pid;
    }

    /* Functions */

    /// @inheritdoc	IVaultAMM
    function deposit(uint256 _amount) external nonReentrant {
        // Safe transfer IN the main asset
        IERC20Upgradeable(pool).safeTransferFrom(
            _msgSender(),
            address(this),
            _amount
        );

        // Call core deposit function
        uint256 _sharesAdded = _deposit(_amount);

        // Emit log
        emit DepositAsset(pool, _amount, _sharesAdded);
    }

    /// @inheritdoc	IVaultAMM
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor
    ) external nonReentrant {
        // Safe transfer IN USD*
        IERC20Upgradeable(stablecoin).safeTransferFrom(
            _msgSender(),
            address(this),
            _amountUSD
        );

        // Get balance of USD
        uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );

        // Swap USD* into token0, token1
        _safeSwap(
            _balUSD / 2,
            stablecoin,
            token0,
            _maxSlippageFactor,
            address(this)
        );
        _safeSwap(
            _balUSD / 2,
            stablecoin,
            token1,
            _maxSlippageFactor,
            address(this)
        );

        // Get token balances
        uint256 _balToken0 = IERC20Upgradeable(token0).balanceOf(address(this));
        uint256 _balToken1 = IERC20Upgradeable(token1).balanceOf(address(this));

        // Add liquidity
        _joinPool(
            token0,
            token1,
            _balToken0,
            _balToken1,
            _maxSlippageFactor,
            address(this)
        );

        // Measure balance of LP token
        uint256 _balLPToken = IERC20Upgradeable(pool).balanceOf(address(this));

        // Call core deposit function
        uint256 _sharesAdded = _deposit(_balLPToken);

        // Emit log
        emit DepositUSD(pool, _amountUSD, _sharesAdded, _maxSlippageFactor);
    }

    /// @notice Core deposit function
    /// @dev Internal deposit function for updating ledger, taking fees, and farming
    /// @param _amount Amount of main asset to deposit
    /// @return sharesAdded Number of shares added/minted
    function _deposit(
        uint256 _amount
    ) internal virtual whenNotPaused returns (uint256 sharesAdded) {
        // Preflight checks
        require(_amount > 0, "negdeposit");

        // Increment main asset total
        assetLockedTotal += _amount;

        // Set sharesAdded to the asset token amount specified
        sharesAdded = _amount;

        // If the total number of shares and asset tokens locked both exceed 0, the shares added is the proportion of asset tokens locked,
        // discounted by the entrance fee
        if (assetLockedTotal > 0 && this.totalSupply() > 0) {
            sharesAdded =
                (_amount * this.totalSupply() * entranceFeeFactor) /
                (assetLockedTotal * BP_DENOMINATOR);

            // Send fee to treasury if a fee is set
            if (entranceFeeFactor < BP_DENOMINATOR) {
                IERC20Upgradeable(asset).safeTransfer(
                    treasury,
                    (_amount * (BP_DENOMINATOR - entranceFeeFactor)) /
                        BP_DENOMINATOR
                );
            }
        }

        // Farm the want token if applicable.
        _farm();

        // Mint ERC20 token proportional to share, and send to msg.sender
        _mint(_msgSender(), sharesAdded);
    }

    /// @notice Internal function for farming Want token. Responsible for staking Want token in a MasterChef/MasterApe-like contract
    function _farm() internal virtual {
        // Check if farmable
        if (isFarmable) {
            // Get LP balance
            uint256 _balLP = IERC20Upgradeable(pool).balanceOf(address(this));

            // Deposit LP tokens into Masterchef contract
            IAMMFarm(farmContract).deposit(pid, _balLP);
        }
    }

    /// @inheritdoc	IVaultAMM
    function withdraw(uint256 _shares) external nonReentrant {
        // Safe Transfer share tokens IN
        IERC20Upgradeable(address(this)).safeTransferFrom(
            _msgSender(),
            address(this),
            _shares
        );

        // Call core withdrawal function
        uint256 _amountWithdrawn = _withdraw(_shares, _msgSender());

        // Emit log
        emit WithdrawAsset(pool, _shares, _amountWithdrawn);
    }

    /// @inheritdoc	IVaultAMM
    function withdrawUSD(
        uint256 _shares,
        uint256 _maxSlippageFactor
    ) external nonReentrant {
        // Safe Transfer share tokens IN
        IERC20Upgradeable(address(this)).safeTransferFrom(
            _msgSender(),
            address(this),
            _shares
        );

        // Call core withdrawal function
        _withdraw(_shares, address(this));

        // Get balance of main asset token and reward token
        uint256 _balAsset = IERC20Upgradeable(asset).balanceOf(address(this));
        uint256 _balRewards = IERC20Upgradeable(farmToken).balanceOf(
            address(this)
        );

        // Remove liquidity
        _exitPool(
            _balAsset,
            pool,
            token0,
            token1,
            _maxSlippageFactor,
            address(this)
        );

        // Calc balance of Tokens 0,1
        uint256 _balToken0 = IERC20Upgradeable(token0).balanceOf(address(this));
        uint256 _balToken1 = IERC20Upgradeable(token1).balanceOf(address(this));

        // Swap Tokens 0,1 to USD*
        if (token0 != stablecoin) {
            _safeSwap(
                _balToken0,
                token0,
                stablecoin,
                _maxSlippageFactor,
                address(this)
            );
        }
        if (token1 != stablecoin) {
            _safeSwap(
                _balToken1,
                token1,
                stablecoin,
                _maxSlippageFactor,
                address(this)
            );
        }

        // Swap rewards token to USD*
        if (farmToken != stablecoin) {
            _safeSwap(
                _balRewards,
                farmToken,
                stablecoin,
                _maxSlippageFactor,
                address(this)
            );
        }

        // Get balances of USD*
        uint256 _balUSD = IERC20Upgradeable(stablecoin).balanceOf(
            address(this)
        );

        // Transfer USD*
        IERC20Upgradeable(stablecoin).safeTransfer(_msgSender(), _balUSD);
    }

    /// @notice Core withdrawal function
    /// @dev Internal withdraw function for unfarming, updating ledger, and transfering remaining investment
    /// @param _shares Number of shares to withdraw
    /// @param _destination Where to send withdrawn funds and rewards
    /// @return amountAsset The quantity of main asset token removed
    function _withdraw(
        uint256 _shares,
        address _destination
    ) internal virtual whenNotPaused returns (uint256 amountAsset) {
        // Preflight checks
        require(_shares > 0, "negShares");

        // Run earn function to harvest and reinvest
        this.earn();

        // Calculate proportional amount of token to unfarm
        uint256 _removableAmount = (_shares * assetLockedTotal) /
            this.totalSupply();

        // Unfarm token if applicable
        _unfarm(_removableAmount);

        // Calculate actual asset unfarmed
        amountAsset = IERC20Upgradeable(asset).balanceOf(address(this));

        // Collect withdrawal fee and deduct from asset balance, if applicable
        if (withdrawFeeFactor < BP_DENOMINATOR) {
            // Modify asset amount, accounting for fee
            amountAsset *= withdrawFeeFactor / BP_DENOMINATOR;

            // Collect fee
            IERC20Upgradeable(asset).safeTransfer(
                treasury,
                (amountAsset * (BP_DENOMINATOR - withdrawFeeFactor)) /
                    BP_DENOMINATOR
            );
        }

        // Re-calculate asset and perform safety cap (for floating point precision)
        uint256 _balAsset = IERC20Upgradeable(asset).balanceOf(address(this));
        if (amountAsset > _balAsset) {
            amountAsset = _balAsset;
        }

        // Transfer the want amount from this contract, to the specified destination (if not the current address)
        if (_destination != address(this)) {
            IERC20Upgradeable(asset).safeTransfer(_destination, amountAsset);
        }

        // Burn the share token
        _burn(address(this), _shares);
    }

    /// @notice Internal function for unfarming Asset token. Responsible for unstaking Asset token from MasterChef/MasterApe contracts
    /// @param _amount the amount of Asset tokens to withdraw. If 0, will only harvest and not withdraw
    function _unfarm(uint256 _amount) internal virtual {
        // Check if farmable
        if (isFarmable) {
            // Withdraw the Asset tokens from the Farm contract
            IAMMFarm(farmContract).withdraw(pid, _amount);
        }
    }

    /// @notice Harvests farm token and reinvests earnings
    function earn() public virtual nonReentrant whenNotPaused {
        // Harvest
        _unfarm(0);

        // Get balance of reward token
        uint256 _balReward = IERC20Upgradeable(farmToken).balanceOf(
            address(this)
        );

        // Check to see if any rewards were obtained
        if (_balReward > 0) {
            // Swap to Tokens 0,1
            _safeSwap(
                _balReward / 2,
                farmToken,
                token0,
                defaultSlippageFactor,
                address(this)
            );
            _safeSwap(
                _balReward / 2,
                farmToken,
                token1,
                defaultSlippageFactor,
                address(this)
            );
        }

        // Get LP token
        uint256 _balToken0 = IERC20Upgradeable(token0).balanceOf(
            address(this)
        );
        uint256 _balToken1 = IERC20Upgradeable(token1).balanceOf(
            address(this)
        );
        _joinPool(
            token0,
            token1,
            _balToken0,
            _balToken1,
            defaultSlippageFactor,
            address(this)
        );

        // Re-deposit LP token
        _farm();
    }

    /* Utilities */

    /// @notice Measures the amount of farmable tokens that has been farmed
    /// @return farmed Total farmed value, in units of farmable token
    function amountFarmed() public view virtual returns (uint256 farmed) {
        (farmed, ) = IAMMFarm(farmContract).userInfo(pid, address(this));
    }

    /// @notice Shows pending (harvestable) farm rewards
    /// @return rewards The number of pending tokens
    function pendingRewards() public view virtual returns (uint256 rewards);
}
