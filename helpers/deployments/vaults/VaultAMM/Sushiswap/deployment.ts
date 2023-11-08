import { chains, vaultFees, zeroAddress } from "../../../../constants";
import { ContractInitList } from "../../../types";
import { VaultAMMInit } from "../types";

const contractInits: ContractInitList<VaultAMMInit> = {
    matic: {
        SUSHI_WMATIC_WETH: {
            asset: chains.matic!.protocols.sushiswap.pools.WMATIC_WETH.pool,
            token0: chains.matic!.tokens.wmatic,
            token1: chains.matic!.tokens.weth,
            pool: chains.matic!.protocols.sushiswap.pools.WMATIC_WETH.pool,
            swapPaths: {
                stablecoinToToken0: [chains.matic!.tokens.usdc, chains.matic!.tokens.wmatic],
                stablecoinToToken1: [chains.matic!.tokens.usdc, chains.matic!.tokens.weth],
                token0ToStablecoin: [chains.matic!.tokens.wmatic, chains.matic!.tokens.usdc],
                token1ToStablecoin: [chains.matic!.tokens.weth, chains.matic!.tokens.usdc],
            },
            priceFeeds: {
                token0: chains.matic!.priceFeeds.matic,
                token1: chains.matic!.priceFeeds.eth,
                eth: chains.matic!.priceFeeds.matic,
                stablecoin: chains.matic!.priceFeeds.usdc,
            },
            baseInit: {
                treasury: chains.matic!.admin.multiSigOwner,
                router: chains.matic!.infra.uniRouterAddress,
                stablecoin: chains.matic!.tokens.usdc,
                tokenWETH: chains.matic!.tokens.wmatic,
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