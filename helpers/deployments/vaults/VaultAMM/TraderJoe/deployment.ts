import { chains, vaultFees, zeroAddress } from "../../../../constants";
import { ContractInitList } from "../../../types";
import { VaultAMMInit } from "../types";

const contractInits: ContractInitList<VaultAMMInit> = {
    avalanche: {
        TJ_AVAX_USDC: {
            asset: chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool,
            token0: chains.avalanche!.tokens.wavax,
            token1: chains.avalanche!.tokens.usdc,
            farmContract: chains.avalanche!.protocols.traderjoe.masterChef!,
            rewardsToken: chains.avalanche!.tokens.joe,
            isFarmable: true,
            pid: chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pid!,
            pool: chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool,
            swapPaths: {
                stablecoinToToken0: [chains.avalanche!.tokens.usdc, chains.avalanche!.tokens.wavax],
                stablecoinToToken1: [],
                token0ToStablecoin: [chains.avalanche!.tokens.wavax, chains.avalanche!.tokens.usdc],
                token1ToStablecoin: [],
                rewardsToToken0: [chains.avalanche!.tokens.joe, chains.avalanche!.tokens.wavax],
                rewardsToToken1: [chains.avalanche!.tokens.joe, chains.avalanche!.tokens.usdc]
            },
            priceFeeds: {
                token0: chains.avalanche!.priceFeeds.avax,
                token1: chains.avalanche!.priceFeeds.usdc,
                stablecoin: chains.avalanche!.priceFeeds.usdc,
                rewards: chains.avalanche!.priceFeeds.joe,
            },
            baseInit: {
                treasury: chains.avalanche!.admin.multiSigOwner,
                router: chains.avalanche!.infra.uniRouterAddress,
                stablecoin: chains.avalanche!.tokens.usdc,
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