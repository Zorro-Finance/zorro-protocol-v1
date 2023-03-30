import { chains, vaultFees, zeroAddress } from "../../../constants";
import { ContractInitList, ControllerXChainInit } from "./types";

const contractInits: ContractInitList<ControllerXChainInit> = {
    avax: {
        layerZeroEndpoint: chains.avax.infra.layerZeroEndpoint,
        stargateRouter: chains.avax.infra.stargateRouter,
        currentChain: chains.avax.xChain.lzChainId,
        sgPoolId: chains.avax.xChain.sgPoolId,
        router: chains.avax.infra.uniRouterAddress,
        stablecoin: chains.avax.tokens.usdc,
        stablecoinPriceFeed: chains.avax.priceFeeds.usdc,
    },
};

export const deploymentArgs = (chain: string, timelockOwner: string) => {
    return [
        contractInits[chain],
        timelockOwner,
    ];
};