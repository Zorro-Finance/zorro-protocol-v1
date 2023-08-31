import { ethers, upgrades } from 'hardhat';
import { verifyContract, uploadContractToDefender, getLatestBeacon, recordBeacon, getMatchingBeaconProxies } from "../../utilities";
import { FormatTypes } from '@ethersproject/abi';
import { PublicNetwork } from '../../../types';
import { recordVaultDeployment } from '../deployment';
import { Contract } from 'ethers';


export const deployAMMVault = async (
    vaultContractClass: string,
    pool: string,
    protocol: string,
    network: string,
    deploymentArgs: any[],
    source: string,
    shouldVerifyContract: boolean = true,
    shouldUploadToDefender: boolean = true,
) => {
    // Init
    let beacon, beaconProxy: Contract;

    // Deploy initial AMM vaults
    const Vault = await ethers.getContractFactory(vaultContractClass);

    // Check if beacon contract exists
    let beaconAddr = await getLatestBeacon(vaultContractClass, network);

    if (beaconAddr) {
        // If beacon exists, upgrade (leave proxy alone)
        beacon = await upgrades.upgradeBeacon(
            beaconAddr,
            Vault,
            {
                kind: 'beacon',
            }
        );

        // Block until deployed
        await beacon.deployed();

        // Log 
        console.log(
            `${vaultContractClass}::${pool} upgraded beacon to ${beaconAddr}`
        );
    } else {
        // If doesn't exist, deploy beacon AND proxy
        beacon = await upgrades.deployBeacon(Vault);

        // Block until deployed
        await beacon.deployed();

        // Assign beacon address
        beaconAddr = beacon.address;

        // Deploy beacon proxy
        beaconProxy = await upgrades.deployBeaconProxy(
            beaconAddr!,
            Vault,
            deploymentArgs,
            {
                kind: 'beacon',
            }
        );

        // Block until deployed
        await beaconProxy.deployed();

        // Record the contract deployment in a lock file
        await recordVaultDeployment(
            vaultContractClass,
            network,
            protocol,
            pool,
            beaconProxy.address,
            source
        );

        // Log 
        console.log(
            `${vaultContractClass}::${pool} proxy deployed to ${beaconProxy.address} and beacon deployed to ${beaconAddr}`
        );
    }

    // Record deployment
    await recordBeacon(vaultContractClass, network, beaconAddr!, source);

    console.log('about to verify contract...');
    
    // Verify contract optionally
    if (shouldVerifyContract) {
        // In this case verify the beacon, not the proxy
        await verifyContract(beaconAddr!, []);
    }

    console.log('about to upload to defender...');

    // Upload contract to Defender
    if (shouldUploadToDefender) {
        // Get all proxies that point to beacon
        const vaults = await getMatchingBeaconProxies(vaultContractClass, network);
        console.log('vaults found in defender upload block: ', vaults);

        // Iterate through each and upload to Defender
        for (let v of vaults) {
            // In this case upload ABI data for the *proxy* not the beacon/implementation
            await uploadContractToDefender({
                network: network as PublicNetwork,
                address: v.deployment_address,
                name: vaultContractClass,
                abi: Vault.interface.format(FormatTypes.json)! as string,
            });
        }
    }
};