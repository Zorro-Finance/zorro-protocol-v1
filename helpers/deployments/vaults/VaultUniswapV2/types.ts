export interface VaultUniswapV2Init {
    priceFeeds: {
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