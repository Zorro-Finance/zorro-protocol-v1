import { chains, vaultFees, zeroAddress } from "../../../constants";
import { ContractInitList, ControllerXChainInit } from "./types";

const contractInits: ContractInitList<ControllerXChainInit> = {
    avalanche: {
        layerZeroEndpoint: chains.avalanche.infra.layerZeroEndpoint,
        stargateRouter: chains.avalanche.infra.stargateRouter,
        currentChain: chains.avalanche.xChain.lzChainId,
        sgPoolId: chains.avalanche.xChain.sgPoolId,
        router: chains.avalanche.infra.uniRouterAddress,
        stablecoin: chains.avalanche.tokens.usdc,
        stablecoinPriceFeed: chains.avalanche.priceFeeds.usdc,
    },
};

export const deploymentArgs = (chain: string, timelockOwner: string) => {
    return [
        contractInits[chain],
        timelockOwner,
    ];
};