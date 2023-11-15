import { chains, vaultFees, zeroAddress } from "../../../constants";
import { ContractInitList } from "../../types";
import { VaultUniswapV2Init } from "./types";

const contractInits: ContractInitList<VaultUniswapV2Init> = {
    matic: {
        priceFeeds: {
            eth: chains.matic!.priceFeeds.matic,
            stablecoin: chains.matic!.priceFeeds.usdc,
        },
        treasury: chains.matic!.admin.multiSigOwner,
        router: chains.matic!.infra.uniRouterAddress,
        stablecoin: chains.matic!.tokens.usdc,
        tokenWETH: chains.matic!.tokens.wmatic,
        entranceFeeFactor: vaultFees.entranceFeeFactor,
        withdrawFeeFactor: vaultFees.withdrawFeeFactor,
        relayer: chains.matic!.admin.relayer,
    },
    avalanche: {
        priceFeeds: {
            eth: chains.avalanche!.priceFeeds.avax,
            stablecoin: chains.avalanche!.priceFeeds.usdc,
        },
        treasury: chains.avalanche!.admin.multiSigOwner,
        router: chains.avalanche!.infra.uniRouterAddress,
        stablecoin: chains.avalanche!.tokens.usdc,
        tokenWETH: chains.avalanche!.tokens.wavax,
        entranceFeeFactor: vaultFees.entranceFeeFactor,
        withdrawFeeFactor: vaultFees.withdrawFeeFactor,
        relayer: chains.avalanche!.admin.relayer,
    }
};

export const deploymentArgs = (chain: string, timelockOwner: string, gov: string) => {
    return [
        contractInits[chain],
        timelockOwner,
        gov
    ];
};