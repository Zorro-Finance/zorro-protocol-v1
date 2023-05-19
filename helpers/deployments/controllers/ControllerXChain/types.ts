export interface ControllerXChainInit {
    layerZeroEndpoint: string;
    stargateRouter: string;
    currentChain: number;
    sgPoolId: number;
    router: string;
    stablecoin: string;
    tokenWETH: string;
    stablecoinPriceFeed: string;
    ethPriceFeed: string;
}

export interface ContractInitList<T> {
    [chain: string]: T;
}