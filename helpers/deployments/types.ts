interface ChainList<VaultType> {
    [vault: string]: VaultType;
}

export interface ContractInitList<VaultType> {
    [chain: string]: ChainList<VaultType>;
}