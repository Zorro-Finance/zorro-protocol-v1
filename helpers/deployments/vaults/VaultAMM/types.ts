export interface VaultAMMInit {
    asset: string;
    token0: string;
    token1: string;
    tokenWETH: string;
    farmContract: string;
    rewardsToken: string;
    isFarmable: boolean;
    pid: number;
    pool: string;
    swapPaths: {
        stablecoinToToken0: string[];
        stablecoinToToken1: string[];
        token0ToStablecoin: string[];
        token1ToStablecoin: string[];
        rewardsToToken0: string[];
        rewardsToToken1: string[];
    },
    priceFeeds: {
        token0: string;
        token1: string;
        eth: string;
        stablecoin: string;
        rewards: string;
    },
    baseInit: {
        treasury: string;
        router: string;
        stablecoin: string;
        entranceFeeFactor: number;
        withdrawFeeFactor: number;
    },
}