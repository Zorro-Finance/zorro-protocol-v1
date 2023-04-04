import { ethers, upgrades } from "hardhat";
import {deploymentArgs} from '../../helpers/deployments/vaults/VaultAMM/TraderJoe/deployment';
import { recordVaultDeployment } from "../../helpers/deployments/utilities";

async function main() {
  // Deploy initial AMM vaults
  const vaultContractClass = 'TraderJoeAMMV1'
  const pool = 'TJ_AVAX_USDC';
  const protocol = 'traderjoe';
  const Vault = await ethers.getContractFactory(vaultContractClass);
  const vault = await upgrades.deployProxy(
    Vault,
    deploymentArgs(network, pool, timelockOwner),
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
    vault.address
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});