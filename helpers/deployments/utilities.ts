import {appendFile, existsSync} from 'fs';
import { ethers, upgrades } from 'hardhat';
import { basename } from "path";

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
    const data = `${vaultContractClass},${network},${protocol},${pool},${deploymentAddress},${source},${getISODateTime()}`;
    const headers = 'vault_contract_class,network,protocol,pool,deployment_address,source,date';
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
    const data = `${contractClass},${network},${deploymentAddress},${source},${getISODateTime()}`;
    const headers = 'contract_class,network,deployment_address,source,date';
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
    deploymentArgs: any[]
) => {
      // Deploy initial AMM vaults
  const Vault = await ethers.getContractFactory(vaultContractClass);
  const vault = await upgrades.deployProxy(
    Vault,
    deploymentArgs,
    {
      kind: 'uups',
    }
  );

  // Log 
  console.log(
    `${vaultContractClass}::${pool} deployed to ${vault.address}`
  );

  // Record the contract deployment in a lock file
  recordVaultDeployment(
    vaultContractClass,
    network,
    protocol,
    pool,
    vault.address,
    basename(__filename)
  );
};