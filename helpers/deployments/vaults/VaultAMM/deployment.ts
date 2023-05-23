import { ethers, upgrades } from 'hardhat';
import { verifyContract, uploadContractToDefender, getLatestBeacon, recordBeacon } from "../../utilities";
import { FormatTypes } from '@ethersproject/abi';
import { PublicNetwork } from '../../../types';
import { recordVaultDeployment } from '../deployment';


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
    // Deploy initial AMM vaults
    const Vault = await ethers.getContractFactory(vaultContractClass);

    // Check if beacon contract exists
    let beacon = await getLatestBeacon(vaultContractClass, network);

    // If doesn't exist, deploy it
    if (!beacon) {
        // Deploy beacon contract
        const beaconProxy = await upgrades.deployBeacon(Vault);
        await beaconProxy.deployed();

        // Assign beacon address
        beacon = beaconProxy.address;

        // Record deployment
        await recordBeacon(vaultContractClass, network, beacon, source);
    }

    // Deploy beacon proxy
    const vault = await upgrades.deployBeaconProxy(
        beacon!,
        Vault,
        deploymentArgs,
        {
            kind: 'beacon',
        }
    );

    // Block until deployed
    await vault.deployed();

    // Log 
    console.log(
        `${vaultContractClass}::${pool} proxy deployed to ${vault.address} and implementation deployed to ${beacon}`
    );

    // Verify contract optionally
    if (shouldVerifyContract) {
        await verifyContract(beacon!, []);
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
    await recordVaultDeployment(
        vaultContractClass,
        network,
        protocol,
        pool,
        vault.address,
        source
    );
};