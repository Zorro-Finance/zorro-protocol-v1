import { ChainList } from "./types";

export const zeroAddress = '0x0000000000000000000000000000000000000000';

export const chains: ChainList = {
    avax: {
        xChain: {
            lzChainId: 106,
            sgPoolId: 1, // USDC
        },
        tokens: {
            wavax: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
            usdc: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
            joe: '0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd',
        },
        priceFeeds: {
            usdc: '0xF096872672F44d6EBA71458D74fe67F9a77a23B9',
            avax: '0x0A77230d17318075983913bC2145DB16C7366156',
            joe: '0x02D35d3a8aC3e1626d3eE09A78Dd87286F5E8e3a',
        },
        infra: {
            uniRouterAddress: '0x60aE616a2155Ee3d9A68541Ba4544862310933d4',
            uniFactoryAddress: '0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10',
            stargateRouter: '0x45A01E4e04F14f7A4a6702c74187c5F6222033cd',
            layerZeroEndpoint: '0x3c2269811836af69497E5F486A85D7316753cf62',
        },
        protocols: {
            traderjoe: {
                pools: {
                    AVAX_USDC: {
                        pool: '0xf4003F4efBE8691B60249E6afbD307aBE7758adb',
                        pid: 0,
                    },
                },
                masterChef: '0x4483f0b6e2F5486D06958C20f8C39A7aBe87bf8F',
            },
        },
        admin: {
            timelockOwner: '0xb7f176e376B883816BA5C63077b6b2E5579538ae',
            multiSigOwner: '0x0426B99e80783CB9b7C0741C9c9E1d0FAb3f80e7',
        },
    },
    polygon: {
        xChain: {
            lzChainId: 109,
            sgPoolId: 1, // USDC
        },
        tokens: {
            wmatic: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
            usdc: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
            weth: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
            sushi: '0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a',
        },
        priceFeeds: {
            usdc: '0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7',
            matic: '0xAB594600376Ec9fD91F8e885dADF0CE036862dE0',
            sushi: '0x49B0c695039243BBfEb8EcD054EB70061fd54aa0',
            eth: '0xF9680D99D6C9589e2a93a78A04A279e509205945',
        },
        infra: {
            uniRouterAddress: '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506',
            uniFactoryAddress: '0xc35DADB65012eC5796536bD9864eD8773aBc74C4',
            stargateRouter: '0x45A01E4e04F14f7A4a6702c74187c5F6222033cd',
            layerZeroEndpoint: '0x3c2269811836af69497E5F486A85D7316753cf62',
        },
        protocols: {
            sushiswap: {
                pools: {
                    WMATIC_WETH: {
                        pool: '0xc4e595acdd7d12fec385e5da5d43160e8a0bac0e',
                        pid: 0,
                    },
                },
                masterChef: '0x0769fd68dFb93167989C6f7254cd0D766Fb2841F',
            },
        },
        admin: {
            timelockOwner: '0xa1Ea1421f9945CcB583eE7083AF6F76503415577',
            multiSigOwner: '0x1cE192d20ccD646d8fF9a47D2C4A364bBD1bea1a',
        },
    },
    bnb: {
        xChain: {
            lzChainId: 102,
            sgPoolId: 5, // BUSD
        },
        tokens: {
            wbnb: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
            busd: '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
        },
        priceFeeds: {
            busd: '0xcBb98864Ef56E9042e7d2efef76141f15731B82f',
            bnb: '0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE',
            cake: '0xB6064eD41d4f67e353768aA239cA86f4F73665a1',
        },
        infra: {
            uniRouterAddress: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
            uniFactoryAddress: '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73',
            stargateRouter: '0x4a364f8c717cAAD9A442737Eb7b8A55cc6cf18D8',
            layerZeroEndpoint: '0x3c2269811836af69497E5F486A85D7316753cf62',
        },
        protocols: {
            pancakeswap: {
                pools: {},
                masterChef: '0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652',
            },
        },
        admin: {
            timelockOwner: zeroAddress, // TODO: Fix
            multiSigOwner: zeroAddress, // TODO: Fix
        },
    },
    avaxtest: {
        xChain: {
            lzChainId: 10106,
            sgPoolId: 2, // USDT
        },
        tokens: {
            usdc: '0x4A0D1092E9df255cf95D72834Ea9255132782318',
        },
        priceFeeds: {},
        infra: {
            layerZeroEndpoint: '0x93f54D755A063cE7bB9e6Ac47Eccc8e33411d706',
            stargateRouter: '0x13093E05Eb890dfA6DacecBdE51d24DabAb2Faa1',
            uniFactoryAddress: zeroAddress,
            uniRouterAddress: zeroAddress,
        },
        protocols: {},
        admin: {
            timelockOwner: zeroAddress,
            multiSigOwner: zeroAddress,
        },
    },
    bnbtest: {
        xChain: {
            lzChainId: 10102,
            sgPoolId: 5, // BUSD
        },
        tokens: {
            busd: '0x1010Bb1b9Dff29e6233E7947e045e0ba58f6E92e',
        },
        priceFeeds: {},
        infra: {
            layerZeroEndpoint: '0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1',
            stargateRouter: '0xbB0f1be1E9CE9cB27EA5b0c3a85B7cc3381d8176',
            uniFactoryAddress: zeroAddress,
            uniRouterAddress: zeroAddress,
        },
        protocols: {},
        admin: {
            timelockOwner: zeroAddress,
            multiSigOwner: zeroAddress,
        },
    },
};

export const vaultFees = {
    entranceFeeFactor: 9900, // 1%
    withdrawFeeFactor: 9900, // 1%
};