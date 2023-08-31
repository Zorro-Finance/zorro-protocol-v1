import { existsSync, createReadStream } from 'fs';
import { ethers } from 'hardhat';
import hre from 'hardhat';
import { AdminClient, Contract } from 'defender-admin-client';
import { TransactionReceipt } from '@ethersproject/providers';
import _ from 'lodash';
import csv from 'csv-parser';
import { createObjectCsvWriter } from 'csv-writer';
import {DateTime} from 'luxon';

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

interface BeaconCSV extends DeploymentCSV {}
interface VaultCSV {
    vault_contract_class: string;
    network: string;
    protocol: string;
    pool: string;
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

export const recordBeacon = async (
    contractClass: string,
    network: string,
    deploymentAddress: string,
    source: string
) => {
    // Prep path and record
    const path = 'deployments/beacons.lock';
    const record: BeaconCSV = {
        contract_class: contractClass,
        network,
        deployment_address: deploymentAddress,
        source,
        date: getISODateTime(),
    };
    
    // Write CSV
    await writeCSV(path, record);

    // Write to general deployment registry
    await recordDeployment(contractClass, network, deploymentAddress, source);
};

export const getLatestBeacon = async (contractClass: string, network: string): Promise<string | undefined> => {
    const path = 'deployments/beacons.lock';

    return new Promise(resolve => {
        if (existsSync(path)) {
            const records: BeaconCSV[] = [];
            createReadStream(path)
                .pipe(csv())
                .on('data', d => records.push(d))
                .on('end', () => {
                    // Find beacon contracts that match the contract class for a given network
                    const matchingRecords = _.filter(records, r => r.contract_class === contractClass && r.network === network);

                    // Return undefined if no matches. Otherewise find the most recent beacon deployment
                    if (matchingRecords.length > 0) {
                        // Map unix timestamps
                        const matchingRecordsWithDate = _.map(matchingRecords, r => ({...r, ...{dt: DateTime.fromISO(r.date).toUnixInteger()}}));
                        // Sort reverse chronologically
                        const matchingRecordsSorted = _.orderBy(matchingRecordsWithDate, ['dt'], ['desc']);
                        // Take most recent deployment
                        resolve(matchingRecordsSorted[0].deployment_address);
                    } else {
                        resolve(undefined);
                    }
                });
        } else {
            resolve(undefined);
        }
    });
};

export const getMatchingBeaconProxies = async (contractClass: string, network: string): Promise<VaultCSV[]> => {
    const path = 'deployments/vaults.lock';

    return new Promise(resolve => {
        if (existsSync(path)) {
            const records: VaultCSV[] = [];
            createReadStream(path)
                .pipe(csv())
                .on('data', d => records.push(d))
                .on('end', () => {
                    // Find beacon contracts that match the contract class for a given network
                    const matchingRecords = _.filter(records, r => r.vault_contract_class === contractClass && r.network === network);

                    resolve(matchingRecords);
                });
        } else {
            resolve([]);
        }
    });
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