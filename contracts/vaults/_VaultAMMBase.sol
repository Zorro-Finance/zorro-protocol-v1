// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../interfaces/Zorro/vaults/IVaultAMM.sol";

import "../interfaces/Uniswap/IAMMFarm.sol";

import "./_VaultBase.sol";

import "../libraries/LPUtility.sol";

// TODO
import "hardhat/console.sol";

/// @title VaultAMMBase
/// @notice Abstract base contract for standard AMM based vaults
abstract contract VaultAMMBase is VaultBase, IVaultAMM {
    /* Libraries */

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeSwapUni for IAMMRouter02;
    using LPUtility for IAMMRouter02;

    /* Constructor */

    /// @notice Upgradeable constructor
    /// @param _initVal A VaultAMMInit struct
    /// @param _timelockOwner The owner address (timelock)
    /// @param _gov The governor address for non timelock admin functions
    function initialize(
        VaultAMMInit memory _initVal,
        address _timelockOwner,
        address _gov
    ) public initializer {
        // Set contract config
        asset = _initVal.asset;
        token0 = _initVal.token0;
        token1 = _initVal.token1;
        farmContract = _initVal.farmContract;
        rewardsToken = _initVal.rewardsToken;
        isFarmable = _initVal.isFarmable;
        pid = _initVal.pid;
        pool = _initVal.pool;

        // Set swap paths
        _setSwapPaths(_initVal.swapPaths.stablecoinToToken0);
        _setSwapPaths(_initVal.swapPaths.stablecoinToToken1);
        _setSwapPaths(_initVal.swapPaths.token0ToStablecoin);
        _setSwapPaths(_initVal.swapPaths.token1ToStablecoin);
        _setSwapPaths(_initVal.swapPaths.rewardsToToken0);
        _setSwapPaths(_initVal.swapPaths.rewardsToToken1);

        // Set price feeds
        _setPriceFeed(token0, _initVal.priceFeeds.token0);
        _setPriceFeed(token1, _initVal.priceFeeds.token1);
        _setPriceFeed(stablecoin, _initVal.priceFeeds.stablecoin);
        _setPriceFeed(rewardsToken, _initVal.priceFeeds.rewards);

        // Call parent constructor
        super.__VaultBase_init(_initVal.baseInit, _timelockOwner, _gov);
    }

    /* State */

    // Accounting
    uint256 public assetLockedTotal;
    uint256 public lastEarn;

    // Key tokens, contracts, and config
    address public asset;
    address public token0;
    address public token1;
    address public farmContract;
    address public rewardsToken;
    bool public isFarmable;
    uint256 public pid;
    address public pool;

    /* Setters */

    /// @notice Sets key tokens/contract addresses for this contract
    /// @param _asset The main asset token
    /// @param _token0 The first token of the LP pair for this contract
    /// @param _token1 The second token of the LP pair for this contract
    /// @param _pool The LP pair address
    function setTokens(
        address _asset,
        address _token0,
        address _token1,
        address _pool
    ) external onlyOwner {
        asset = _asset;
        token0 = _token0;
        token1 = _token1;
        pool = _pool;
    }

    /// @notice Sets farm params for this contract (Masterchef)
    /// @param _isFarmable Whether AMM protocol rewards are available
    /// @param _farmContract The farm contract (Masterchef) address
    /// @param _rewardsToken The reward token address
    /// @param _pid The pool ID (pid) on the farm contract representing this pool
    function setFarmParams(
        bool _isFarmable,
        address _farmContract,
        address _rewardsToken,
        uint256 _pid
    ) external onlyOwner {
        isFarmable = _isFarmable;
        farmContract = _farmContract;
        rewardsToken = _rewardsToken;
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

    /// @inheritdoc	IVault
    function depositUSD(
        uint256 _amountUSD,
        uint256 _maxSlippageFactor
    ) external nonReentrant {
        console.log("Entered deposit with amount %s", _amountUSD);

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
        console.log("Transferred USD IN successfully. Bal: %s", _balUSD);

        // Swap USD* into token0, token1 (if applicable)
        if (token0 != stablecoin) {
            IAMMRouter02(router).safeSwap(
                _balUSD / 2,
                stablecoin,
                token0,
                swapPaths[stablecoin][token0],
                priceFeeds[stablecoin],
                priceFeeds[token0],
                _maxSlippageFactor,
                address(this)
            );
        }

        if (token1 != stablecoin) {
            IAMMRouter02(router).safeSwap(
                _balUSD / 2,
                stablecoin,
                token1,
                swapPaths[stablecoin][token1],
                priceFeeds[stablecoin],
                priceFeeds[token1],
                _maxSlippageFactor,
                address(this)
            );
        }


        // Get token balances
        uint256 _balToken0 = IERC20Upgradeable(token0).balanceOf(address(this));
        uint256 _balToken1 = IERC20Upgradeable(token1).balanceOf(address(this));
        console.log("swaps completed. Bal0: %s, Bal1: %s", _balToken0, _balToken1);

        // Add liquidity
        IAMMRouter02(router).joinPool(
            token0,
            token1,
            _balToken0,
            _balToken1,
            _maxSlippageFactor,
            address(this)
        );

        // Measure balance of LP token
        uint256 _balLPToken = IERC20Upgradeable(pool).balanceOf(address(this));

        console.log("joined pool. Bal LP token: %s", _balLPToken);

        // Call core deposit function
        uint256 _sharesAdded = _deposit(_balLPToken);

        console.log("Added shares successfully: %s", _sharesAdded);

        // Emit log
        emit DepositUSD(pool, _amountUSD, _sharesAdded, _maxSlippageFactor);

        console.log("FIN");
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


        if (isFarmable) {
            // Farm the want token if applicable.
            _farm();
        } else {
            // Otherewise, simply increment main asset total
            assetLockedTotal += _amount;
        }

        // Mint ERC20 token proportional to share, and send to msg.sender
        _mint(_msgSender(), sharesAdded);
    }

    /// @notice Internal function for farming Want token. Responsible for staking Want token in a MasterChef/MasterApe-like contract
    function _farm() internal virtual whenNotPaused {
        // Get LP balance
        uint256 _balLP = IERC20Upgradeable(pool).balanceOf(address(this));

        // Increment asset locked total by additional LP tokens earned/deposited onto this contract
        assetLockedTotal += _balLP;

        // Allow spending
        IERC20Upgradeable(pool).safeIncreaseAllowance(farmContract, _balLP);

        // Deposit LP tokens into Masterchef contract
        IAMMFarm(farmContract).deposit(pid, _balLP);
    }

    /// @inheritdoc	IVaultAMM
    function withdraw(
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
        (uint256 _amountWithdrawn, bool _didSkipEarn) = _withdraw(
            _shares,
            _msgSender(),
            _maxSlippageFactor
        );

        // Emit log
        emit WithdrawAsset(pool, _shares, _amountWithdrawn, _didSkipEarn);
    }

    /// @inheritdoc	IVault
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
        (, bool _didSkipEarn) = _withdraw(
            _shares,
            address(this),
            _maxSlippageFactor
        );

        // Get balance of main asset token and reward token
        uint256 _balAsset = IERC20Upgradeable(asset).balanceOf(address(this));

        // Remove liquidity
        IAMMRouter02(router).exitPool(
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
            IAMMRouter02(router).safeSwap(
                _balToken0,
                token0,
                stablecoin,
                swapPaths[token0][stablecoin],
                priceFeeds[token0],
                priceFeeds[stablecoin],
                _maxSlippageFactor,
                address(this)
            );
        }
        if (token1 != stablecoin) {
            IAMMRouter02(router).safeSwap(
                _balToken1,
                token1,
                stablecoin,
                swapPaths[token1][stablecoin],
                priceFeeds[token1],
                priceFeeds[stablecoin],
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

        // Emit log
        emit WithdrawUSD(
            pool,
            _balUSD,
            _shares,
            _didSkipEarn,
            _maxSlippageFactor
        );
    }

    /// @notice Core withdrawal function
    /// @dev Internal withdraw function for unfarming, updating ledger, and transfering remaining investment
    /// @param _shares Number of shares to withdraw
    /// @param _destination Where to send withdrawn funds and rewards
    /// @param _maxSlippageFactor The slippage tolerance (9900 = 1%)
    /// @return amountAsset The quantity of main asset token removed
    /// @return didSkipEarn Whether earn function was skipped
    function _withdraw(
        uint256 _shares,
        address _destination,
        uint256 _maxSlippageFactor
    )
        internal
        virtual
        whenNotPaused
        returns (uint256 amountAsset, bool didSkipEarn)
    {
        // Preflight checks
        require(_shares > 0, "negShares");

        // Attempt to run earn()
        didSkipEarn = this.earn(_maxSlippageFactor, true);

        // Calculate proportional amount of token to unfarm
        uint256 _removableAmount = (_shares * assetLockedTotal) /
            this.totalSupply();

        // Unfarm token if applicable
        _unfarm(_removableAmount);

        // Calculate actual asset unfarmed
        amountAsset = IERC20Upgradeable(asset).balanceOf(address(this));

        // Decrement main asset total
        assetLockedTotal -= amountAsset;

        // Collect withdrawal fee and deduct from asset balance, if applicable
        if (withdrawFeeFactor < BP_DENOMINATOR) {
            uint256 _fee = (amountAsset *
                (BP_DENOMINATOR - withdrawFeeFactor)) / BP_DENOMINATOR;

            // Collect fee
            IERC20Upgradeable(asset).safeTransfer(treasury, _fee);

            // Decrement amount asset
            amountAsset -= _fee;
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
    function _unfarm(uint256 _amount) internal virtual whenNotPaused {
        // Check if farmable
        if (isFarmable) {
            // Safety: Account for any rounding errors
            if (_amount > this.amountFarmed()) {
                _amount = this.amountFarmed();
            }

            // Withdraw the Asset tokens from the Farm contract
            IAMMFarm(farmContract).withdraw(pid, _amount);
        }
    }

    /// @notice Harvests farm token and reinvests earnings
    /// @param _maxSlippageFactor The slippage tolerance (9900 = 1%)
    /// @param _softFail Checks to see if swaps are possible with low rewards, and skips if not
    /// @return didSkip Registers true if _softFail was set and the function could not complete (i.e. due to swap not being possible)
    function earn(
        uint256 _maxSlippageFactor,
        bool _softFail
    ) public virtual whenNotPaused returns (bool didSkip) {
        // Update rewards
        this.updateRewards();

        // Harvest
        _unfarm(0);

        // Get balance of reward token
        uint256 _balReward = IERC20Upgradeable(rewardsToken).balanceOf(
            address(this)
        );

        // Check to see if swap is possible, if softFail set
        if (_softFail) {
            // Swaps can fail if not enough rewards have been earned since last earn block
            // If not swappable, exit early

            for (uint8 i = 0; i < 2; i++) {
                // Determine token, and skip swap check if same as rewardToken
                address _token = i == 0 ? token0 : token1;
                if (_token == rewardsToken) {
                    continue;
                }

                bool _isSwappable = IAMMRouter02(router).checkIsSwappable(
                    _balReward,
                    rewardsToken,
                    _token,
                    swapPaths[rewardsToken][_token],
                    priceFeeds[rewardsToken],
                    priceFeeds[_token],
                    _maxSlippageFactor
                );

                if (!_isSwappable) {
                    didSkip = true;
                    return didSkip;
                }
            }
        }

        // Check to see if any rewards were obtained
        if (_balReward > 0) {
            // Swap to Tokens 0,1
            if (rewardsToken != token0) {
                IAMMRouter02(router).safeSwap(
                    _balReward / 2,
                    rewardsToken,
                    token0,
                    swapPaths[rewardsToken][token0],
                    priceFeeds[rewardsToken],
                    priceFeeds[token0],
                    _maxSlippageFactor,
                    address(this)
                );
            }
            if (rewardsToken != token1) {
                IAMMRouter02(router).safeSwap(
                    _balReward / 2,
                    rewardsToken,
                    token1,
                    swapPaths[rewardsToken][token1],
                    priceFeeds[rewardsToken],
                    priceFeeds[token1],
                    _maxSlippageFactor,
                    address(this)
                );
            }
        }

        // Get LP token
        uint256 _balToken0 = IERC20Upgradeable(token0).balanceOf(address(this));
        uint256 _balToken1 = IERC20Upgradeable(token1).balanceOf(address(this));

        // Join pool
        IAMMRouter02(router).joinPool(
            token0,
            token1,
            _balToken0,
            _balToken1,
            _maxSlippageFactor,
            address(this)
        );

        // Re-deposit LP token
        _farm();

        // Update lastEarn block number
        lastEarn = block.number;

        // Emit log
        emit ReinvestEarnings(_balReward, asset);
    }

    /* Utilities */

    /// @notice Measures the amount of farmable tokens that has been farmed
    /// @return farmed Total farmed value, in units of farmable token
    function amountFarmed() public view virtual returns (uint256 farmed) {
        (farmed, ) = IAMMFarm(farmContract).userInfo(pid, address(this));
    }

    /// @notice Updates the pool rewards on the farm contract
    function updateRewards() public virtual;

    /// @notice Shows pending (harvestable) farm rewards
    /// @return rewards The number of pending tokens
    function pendingRewards() public view virtual returns (uint256 rewards);
}
