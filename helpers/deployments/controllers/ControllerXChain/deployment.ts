import { chains, vaultFees, zeroAddress } from "../../../constants";
import { ContractInitList, ControllerXChainInit } from "./types";

const contractInits: ContractInitList<ControllerXChainInit> = {
    avalanche: {
        layerZeroEndpoint: chains.avalanche!.infra.layerZeroEndpoint,
        stargateRouter: chains.avalanche!.infra.stargateRouter,
        currentChain: chains.avalanche!.xChain.lzChainId,
        sgPoolId: chains.avalanche!.xChain.sgPoolId,
        router: chains.avalanche!.infra.uniRouterAddress,
        stablecoin: chains.avalanche!.tokens.usdc,
        stablecoinPriceFeed: chains.avalanche!.priceFeeds.usdc,
    },
    matic: {
        layerZeroEndpoint: chains.matic!.infra.layerZeroEndpoint,
        stargateRouter: chains.matic!.infra.stargateRouter,
        currentChain: chains.matic!.xChain.lzChainId,
        sgPoolId: chains.matic!.xChain.sgPoolId,
        router: chains.matic!.infra.uniRouterAddress,
        stablecoin: chains.matic!.tokens.usdc,
        stablecoinPriceFeed: chains.matic!.priceFeeds.usdc,
    },
};

export const deploymentArgs = (chain: string, timelockOwner: string) => {
    return [
        contractInits[chain],
        timelockOwner,
    ];
};