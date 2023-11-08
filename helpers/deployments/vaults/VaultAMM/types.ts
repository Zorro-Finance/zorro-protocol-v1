export interface VaultAMMInit {
    asset: string;
    token0: string;
    token1: string;
    pool: string;
    swapPaths: {
        stablecoinToToken0: string[];
        stablecoinToToken1: string[];
        token0ToStablecoin: string[];
        token1ToStablecoin: string[];
    },
    priceFeeds: {
        token0: string;
        token1: string;
        eth: string;
        stablecoin: string;
    },
    baseInit: {
        treasury: string;
        router: string;
        stablecoin: string;
        tokenWETH: string;
        entranceFeeFactor: number;
        withdrawFeeFactor: number;
    },
}