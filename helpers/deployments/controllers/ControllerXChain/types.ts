export interface ControllerXChainInit {
    layerZeroEndpoint: string;
    stargateRouter: string;
    currentChain: number;
    sgPoolId: number;
    router: string;
    stablecoin: string;
    stablecoinPriceFeed: string;
}

export interface ContractInitList<T> {
    [chain: string]: T;
}