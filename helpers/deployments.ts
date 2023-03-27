import { zeroAddress } from "./constants";

const vaultAMMInit = (): any => ({
    asset: zeroAddress,
    token0: zeroAddress,
    token1: zeroAddress,
    farmContract: zeroAddress,
    rewardsToken: zeroAddress,
    isFarmable: true,
    pid: 0,
    pool: zeroAddress,
    swapPaths: {
        stablecoinToToken0: [],
        stablecoinToToken1: [],
        token0ToStablecoin: [],
        token1ToStablecoin: [],
        rewardsToToken0: [],
        rewardsToToken1: []
    },
    priceFeeds: {
        token0: zeroAddress,
        token1: zeroAddress,
        stablecoin: zeroAddress,
        rewards: zeroAddress,
    },
    baseInit: {
        treasury: zeroAddress,
        router: zeroAddress,
        stablecoin: zeroAddress,
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