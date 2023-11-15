import { network } from "hardhat";

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
    multiSigOwner: string;
    relayer: string;
}

interface ChainConfig {
    xChain: XChainConfig;
    tokens: TokenList;
    priceFeeds: PriceFeedList;
    infra: InfraConfig;
    protocols: ProtocolConfigList;
    admin: AdminConfig;
}

export type ChainList = {
    [network in PublicNetwork]: ChainConfig;
};

export type ChainListOpt = Partial<ChainList>;

// Mimic OZ Defender types (node_modules/defender-base-client/lib/utils/network.d.ts)
export type PublicNetwork = 'mainnet' | 'goerli' | 'xdai' | 'sokol' | 'fuse' | 'bsc' | 'bsctest' | 'fantom' | 'fantomtest' | 'moonbase' | 'moonriver' | 'moonbeam' | 'matic' | 'mumbai' | 'avalanche' | 'fuji' | 'optimism' | 'optimism-goerli' | 'arbitrum' | 'arbitrum-nova' | 'arbitrum-goerli' | 'celo' | 'alfajores' | 'harmony-s0' | 'harmony-test-s0' | 'aurora' | 'auroratest' | 'hedera' | 'hederatest' | 'zksync' | 'zksync-goerli';