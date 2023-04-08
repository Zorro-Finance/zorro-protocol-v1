import { chains, vaultFees, zeroAddress } from "../../../../constants";
import { ContractInitList } from "../../../types";
import { VaultAMMInit } from "../types";

const contractInits: ContractInitList<VaultAMMInit> = {
    polygon: {
        SUSHI_WMATIC_WETH: {
            asset: chains.polygon.protocols.sushiswap.pools.WMATIC_WETH.pool,
            token0: chains.polygon.tokens.wmatic,
            token1: chains.polygon.tokens.weth,
            farmContract: chains.polygon.protocols.sushiswap.masterChef!,
            rewardsToken: chains.polygon.tokens.sushi,
            isFarmable: false,
            pid: chains.polygon.protocols.sushiswap.pools.WMATIC_WETH.pid!,
            pool: chains.polygon.protocols.sushiswap.pools.WMATIC_WETH.pool,
            swapPaths: {
                stablecoinToToken0: [chains.polygon.tokens.usdc, chains.polygon.tokens.wmatic],
                stablecoinToToken1: [chains.polygon.tokens.usdc, chains.polygon.tokens.weth],
                token0ToStablecoin: [chains.polygon.tokens.wmatic, chains.polygon.tokens.usdc],
                token1ToStablecoin: [chains.polygon.tokens.weth, chains.polygon.tokens.usdc],
                rewardsToToken0: [chains.polygon.tokens.sushi, chains.polygon.tokens.wmatic],
                rewardsToToken1: [chains.polygon.tokens.sushi, chains.polygon.tokens.weth]
            },
            priceFeeds: {
                token0: chains.polygon.priceFeeds.matic,
                token1: chains.polygon.priceFeeds.eth,
                stablecoin: chains.polygon.priceFeeds.usdc,
                rewards: chains.polygon.priceFeeds.sushi,
            },
            baseInit: {
                treasury: chains.polygon.admin.multiSigOwner,
                router: chains.polygon.infra.uniRouterAddress,
                stablecoin: chains.polygon.tokens.usdc,
                entranceFeeFactor: vaultFees.entranceFeeFactor,
                withdrawFeeFactor: vaultFees.withdrawFeeFactor,
            },
        },
    },
};

export const deploymentArgs = (chain: string, pool: string, timelockOwner: string, gov: string) => {
    return [
        contractInits[chain][pool],
        timelockOwner,
        gov
    ];
};