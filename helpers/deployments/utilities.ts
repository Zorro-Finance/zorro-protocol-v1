import { existsSync } from 'fs';
import { ethers } from 'hardhat';
import hre from 'hardhat';
import { AdminClient, Contract } from 'defender-admin-client';
import { TransactionReceipt } from '@ethersproject/providers';
import _ from 'lodash';
import { createObjectCsvWriter } from 'csv-writer';

export const getISODateTime = (): string => {
    return (new Date()).toISOString();
}

interface DeploymentCSV {
    contract_class: string;
    network: string;
    deployment_address: string;
    source: string;
    date: string;
}

export const recordDeployment = async (
    contractClass: string,
    network: string,
    deploymentAddress: string,
    source: string
) => {
    // Prep path and record
    const path = 'deployments/contracts.lock';
    const record: DeploymentCSV = {
        contract_class: contractClass,
        network,
        deployment_address: deploymentAddress,
        source,
        date: getISODateTime(),
    };

    // Write CSV
    await writeCSV(path, record);
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

export const eventDidEmit = (abiFragment: string, receipt: TransactionReceipt): boolean => {
    const sig = ethers.utils.id(abiFragment);
    return !!_.find(receipt.logs, (l: any) => l.topics[0] === sig);
}

export const writeCSV = async (path: string, record: any) => {
    // Prep writer
    const csvWriter = createObjectCsvWriter({
        path,
        header: _.map(_.keys(record), k => ({id: k, title: k})),
        append: existsSync(path),
    });

    // Write
    await csvWriter.writeRecords([record]);
};