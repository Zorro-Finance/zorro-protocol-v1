import {writeFile} from 'fs';

export const recordVaultDeployment = (
    vaultContractClass: string,
    network: string,
    protocol: string,
    pool: string,
    deploymentAddress: string 
) => {
    const data = `${vaultContractClass} ${network} ${protocol} ${pool} ${deploymentAddress}`;
    writeFile('deployments/vaults.lock', data, err => {
        if (err) {
            console.error(err);
        }
    });

    // Write to general 
    recordDeployment(vaultContractClass, network, deploymentAddress);
};

export const recordDeployment = (
    vaultContractClass: string,
    network: string,
    deploymentAddress: string 
) => {
    const data = `${vaultContractClass} ${network} ${deploymentAddress}`;
    writeFile('deployments/contracts.lock', data, err => {
        if (err) {
            console.error(err);
        }
    });
};

// TODO: Make sure that the CSV is in append mode
// TODO: Write header file