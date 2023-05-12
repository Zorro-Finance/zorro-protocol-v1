import { appendFile, existsSync } from 'fs';
import { ethers, upgrades } from 'hardhat';
import hre from 'hardhat';
import { AdminClient, Contract } from 'defender-admin-client';
import { FormatTypes } from '@ethersproject/abi';
import { PublicNetwork } from '../types';

const getISODateTime = (): string => {
    return (new Date()).toISOString();
}

export const recordVaultDeployment = (
    vaultContractClass: string,
    network: string,
    protocol: string,
    pool: string,
    deploymentAddress: string,
    source: string
) => {
    const data = `${vaultContractClass},${network},${protocol},${pool},${deploymentAddress},${source},${getISODateTime()}\n`;
    const headers = 'vault_contract_class,network,protocol,pool,deployment_address,source,date\n';
    const path = 'deployments/vaults.lock';
    if (!existsSync(path)) {
        // Add header row
        appendFile(path, headers, err => {
            if (err) {
                console.error(err);
            }
        });
    }
    // Add data row
    appendFile(path, data, err => {
        if (err) {
            console.error(err);
        }
    });

    // Write to general 
    recordDeployment(vaultContractClass, network, deploymentAddress, source);
};

export const recordDeployment = (
    contractClass: string,
    network: string,
    deploymentAddress: string,
    source: string
) => {
    const data = `${contractClass},${network},${deploymentAddress},${source},${getISODateTime()}\n`;
    const headers = 'contract_class,network,deployment_address,source,date\n';
    const path = 'deployments/contracts.lock';
    if (!existsSync(path)) {
        // Add header row
        appendFile(path, headers, err => {
            if (err) {
                console.error(err);
            }
        });
    }
    // Add data row
    appendFile(path, data, err => {
        if (err) {
            console.error(err);
        }
    });
};

export const deployAMMVault = async (
    vaultContractClass: string,
    pool: string,
    protocol: string,
    network: string,
    deploymentArgs: any[],
    source: string,
    shouldVerifyContract: boolean = true,
    shouldUploadToDefender: boolean = true
) => {
    // Deploy initial AMM vaults
    const Vault = await ethers.getContractFactory(vaultContractClass);
    // TODO: Create tests for forwarding

    // Deploy beacon contract
    const beacon = await upgrades.deployBeacon(Vault);
    await beacon.deployed();

    // Deploy beacon proxy
    const vault = await upgrades.deployBeaconProxy(
        beacon,
        Vault,
        deploymentArgs,
        {
            kind: 'beacon',
        }
    );
    await vault.deployed();

    // Block until deployed
    await vault.deployed();

    // Log 
    console.log(
        `${vaultContractClass}::${pool} proxy deployed to ${vault.address} and implementation deployed to ${beacon.address}`
    );

    // Verify contract optionally
    if (shouldVerifyContract) {
        await verifyContract(beacon.address, []);
    }

    // Upload contract to Defender
    if (shouldUploadToDefender) {
        await uploadContractToDefender({
            network: network as PublicNetwork,
            address: vault.address,
            name: vaultContractClass,
            abi: Vault.interface.format(FormatTypes.json)! as string
        });
    }

    // Record the contract deployment in a lock file
    recordVaultDeployment(
        vaultContractClass,
        network,
        protocol,
        pool,
        vault.address,
        source
    );
};

export const verifyContract = async (
    implementationAddress: string,
    constructorArguments: any[]
) => {
    await hre.run("verify:verify", {
        address: implementationAddress,
        constructorArguments,
    });
};

export const uploadContractToDefender = async (contract: Contract) => {
    const client = new AdminClient({ apiKey: process.env.DEFENDER_API_KEY!, apiSecret: process.env.DEFENDER_API_SECRET! });

    await client.addContract(contract);
};