import {deploymentArgs} from '../../helpers/deployments/vaults/VaultAMM/Sushiswap/deployment';
import { deployAMMVault } from "../../helpers/deployments/utilities";
import hre from 'hardhat';
import { chains } from "../../helpers/constants";

async function main() {
  // Init
  const network = hre.network.name;

  // Network check
  if (network !== 'polygon') {
    return;
  }
  
  // Deploy initial AMM vaults
  const vaultContractClass = 'SushiSwapAMM'
  const pool = 'WMATIC_WETH';
  const protocol = 'sushiswap';

  await deployAMMVault(
    vaultContractClass,
    pool,
    protocol,
    network,
    deploymentArgs(network, pool, chains[network].admin.timelockOwner, chains[network].admin.multiSigOwner)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});