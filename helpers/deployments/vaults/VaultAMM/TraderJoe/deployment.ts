import { chains, vaultFees, zeroAddress } from "../../../../constants";
import { ContractInitList } from "../../../types";
import { VaultAMMInit } from "../types";

const contractInits: ContractInitList<VaultAMMInit> = {
    avax: {
        TJ_AVAX_USDC: {
            asset: chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool,
            token0: chains.avax.tokens.wavax,
            token1: chains.avax.tokens.usdc,
            farmContract: chains.avax.protocols.traderjoe.masterChef!,
            rewardsToken: chains.avax.tokens.joe,
            isFarmable: true,
            pid: chains.avax.protocols.traderjoe.pools.AVAX_USDC.pid!,
            pool: chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool,
            swapPaths: {
                stablecoinToToken0: [chains.avax.tokens.usdc, chains.avax.tokens.wavax],
                stablecoinToToken1: [],
                token0ToStablecoin: [chains.avax.tokens.wavax, chains.avax.tokens.usdc],
                token1ToStablecoin: [],
                rewardsToToken0: [chains.avax.tokens.joe, chains.avax.tokens.wavax],
                rewardsToToken1: [chains.avax.tokens.joe, chains.avax.tokens.usdc]
            },
            priceFeeds: {
                token0: chains.avax.priceFeeds.avax,
                token1: chains.avax.priceFeeds.usdc,
                stablecoin: chains.avax.priceFeeds.usdc,
                rewards: chains.avax.priceFeeds.joe,
            },
            baseInit: {
                treasury: chains.avax.admin.multiSigOwner,
                router: chains.avax.infra.uniRouterAddress,
                stablecoin: chains.avax.tokens.usdc,
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