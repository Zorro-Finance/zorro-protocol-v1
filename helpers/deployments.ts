const vaultAMMInit = () => ({
    asset: '',
    token0: '',
    token1: '',
    farmContract: '',
    rewardsToken: '',
    isFarmable: true,
    pid: 0,
    pool: '',
    swapPaths: {
        stablecoinToToken0: [],
        stablecoinToToken1: [],
        token0ToStablecoin: [],
        token1ToStablecoin: [],
        rewardsToToken0: [],
        rewardsToToken1: []
    },
    priceFeeds: {
        token0: '',
        token1: '',
        stablecoin: '',
        rewards: '',
    },
    baseInit: {
        treasury: '',
        router: '',
        stablecoin: '',
        entranceFeeFactor: 0,
        withdrawFeeFactor: 0,
    },
});

export const deploymentArgs = (timelockOwner: string) => ({
    avax: {
        VaultAMM: {
            TJ_AVAX_USDC: [
                vaultAMMInit(),
                timelockOwner,
            ],
        },
    },
});