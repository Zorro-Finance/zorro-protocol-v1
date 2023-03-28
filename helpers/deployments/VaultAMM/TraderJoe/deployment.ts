import { chains, zeroAddress } from "../../../constants";
import { ContractInitList } from "../../types";
import { VaultAMMInit } from "../types";

const contractInits: ContractInitList<VaultAMMInit> = {
    avax: {
        TJ_AVAX_USDC: {
            asset: zeroAddress,
            token0: chains.avax.tokens.wavax,
            token1: chains.avax.tokens.usdc,
            farmContract: chains.avax.protocols.traderjoe.masterChef,
            rewardsToken: chains.avax.tokens.joe,
            isFarmable: true,
            pid: chains.avax.protocols.traderjoe.pidAVAX_USDC,
            pool: chains.avax.protocols.traderjoe.poolAVAX_USDC,
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
                entranceFeeFactor: 9900,
                withdrawFeeFactor: 9900,
            },
        },
    },
};

export const deploymentArgs = (chain: string, pool: string, timelockOwner: string) => {
    return [
        contractInits[chain][pool],
        timelockOwner,
    ];
};