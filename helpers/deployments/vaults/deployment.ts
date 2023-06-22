import { getISODateTime, recordDeployment, writeCSV } from "../utilities";
import _ from 'lodash';

interface VaultAMMRecordCSV {
    vaultContractClass: string;
    network: string;
    protocol: string;
    pool: string;
    deploymentAddress: string;
    source: string;
    date: string;
}

export const recordVaultDeployment = async (
    vaultContractClass: string,
    network: string,
    protocol: string,
    pool: string,
    deploymentAddress: string,
    source: string
) => {
    // Prep path and record
    const path = 'deployments/vaults.lock';
    const record: VaultAMMRecordCSV = {
        vaultContractClass,
        network,
        protocol,
        pool,
        deploymentAddress,
        source,
        date: getISODateTime(),
    };

    // Write CSV
    await writeCSV(path, record);

    // Write to general deployment registry
    await recordDeployment(vaultContractClass, network, deploymentAddress, source);
};