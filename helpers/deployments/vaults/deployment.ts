import { getISODateTime, recordDeployment, writeCSV } from "../utilities";
import _ from 'lodash';

interface VaultRecordCSV {
    vaultName: string;
    vaultContractClass: string;
    network: string;
    protocol: string;
    deploymentAddress: string;
    source: string;
    date: string;
}

export const recordVaultDeployment = async (
    vaultName: string,
    vaultContractClass: string,
    network: string,
    protocol: string,
    deploymentAddress: string,
    source: string
) => {
    // Prep path and record
    const path = 'deployments/vaults.lock';
    const record: VaultRecordCSV = {
        vaultName,
        vaultContractClass,
        network,
        protocol,
        deploymentAddress,
        source,
        date: getISODateTime(),
    };

    // Write CSV
    await writeCSV(path, record);

    // Write to general deployment registry
    await recordDeployment(vaultContractClass, network, deploymentAddress, source);
};