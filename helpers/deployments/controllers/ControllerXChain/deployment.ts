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
        tokenWETH: chains.avalanche!.tokens.wavax,
        stablecoinPriceFeed: chains.avalanche!.priceFeeds.usdc,
        ethPriceFeed: chains.avalanche!.priceFeeds.avax,
    },
    matic: {
        layerZeroEndpoint: chains.matic!.infra.layerZeroEndpoint,
        stargateRouter: chains.matic!.infra.stargateRouter,
        currentChain: chains.matic!.xChain.lzChainId,
        sgPoolId: chains.matic!.xChain.sgPoolId,
        router: chains.matic!.infra.uniRouterAddress,
        stablecoin: chains.matic!.tokens.usdc,
        tokenWETH: chains.matic!.tokens.wmatic,
        stablecoinPriceFeed: chains.matic!.priceFeeds.usdc,
        ethPriceFeed: chains.matic!.priceFeeds.matic,
    },
};

export const deploymentArgs = (chain: string, timelockOwner: string) => {
    return [
        contractInits[chain],
        timelockOwner,
    ];
};