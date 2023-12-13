import { ethers, upgrades } from 'hardhat';
import { FormatTypes } from '@ethersproject/abi';
import { PublicNetwork } from '../../types';
import { 
    getISODateTime, 
    recordDeployment, 
    writeCSV,
    uploadContractToDefender,
    verifyContract,
} from "../utilities";
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

export const deployVault = async (
    vaultName: string,
    vaultContractClass: string,
    network: string,
    protocol: string,
    deploymentArgs: any[],
    source: string,
    shouldVerifyContract: boolean = true,
    shouldUploadToDefender: boolean = true,
) => {
    // Deploy initial vaults
    const Vault = await ethers.getContractFactory(vaultContractClass);
    const vault = await upgrades.deployProxy(
        Vault,
        deploymentArgs,
        {
            kind: 'uups',
        }
    )

    // Block until deployed
    await vault.deployed();

    // Verify contract and send to Etherscan (if applicable)
    if (shouldVerifyContract) {
        await verifyContract(await upgrades.erc1967.getImplementationAddress(vault.address), []);
    }

    // Upload contract to Defender (if applicable)
    if (shouldUploadToDefender) {
        await uploadContractToDefender({
            network: network as PublicNetwork,
            address: vault.address,
            name: vaultName,
            abi: Vault.interface.format(FormatTypes.json)! as string
        });
    }

    // Log 
    console.log(
        `Vault ${vaultName} (class: ${vaultContractClass}) deployed to ${vault.address}`
    );

    // Record the contract deployment in a lock file
    recordVaultDeployment(
        vaultName,
        vaultContractClass,
        network,
        protocol,
        vault.address,
        source
    );
};