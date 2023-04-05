interface XChainConfig {
    lzChainId: number;
    sgPoolId: number;
}

interface TokenList {
    [token: string]: string;
}

interface PriceFeedList {
    [token: string]: string;
}

interface InfraConfig {
    uniRouterAddress: string;
    uniFactoryAddress: string;
    stargateRouter: string;
    layerZeroEndpoint: string;
}

interface PoolConfig {
    pool: string;
    pid?: number;
}

interface PoolConfigList {
    [pool: string]: PoolConfig;
}

interface ProtocolConfig {
    pools: PoolConfigList;
    masterChef?: string;
}

interface ProtocolConfigList {
    [protocol: string]: ProtocolConfig;
}

interface AdminConfig {
    timelockOwner: string;
    treasury: string;
}

interface ChainConfig {
    xChain: XChainConfig;
    tokens: TokenList;
    priceFeeds: PriceFeedList;
    infra: InfraConfig;
    protocols: ProtocolConfigList;
    admin: AdminConfig;
}

export interface ChainList {
    [network: string]: ChainConfig;
}