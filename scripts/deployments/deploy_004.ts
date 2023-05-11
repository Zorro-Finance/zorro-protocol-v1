import {deploymentArgs} from '../../helpers/deployments/vaults/VaultAMM/Sushiswap/deployment';
import { deployAMMVault } from "../../helpers/deployments/utilities";
import { chains } from "../../helpers/constants";
import { basename } from 'path';
import hre from 'hardhat';
import { PublicNetwork } from '../../helpers/types';

async function main() {
  // Init
  const network = hre.network.name as PublicNetwork;

  // Network check
  if (network !== 'matic') {
    return;
  }
  
  // Deploy initial AMM vaults
  const vaultContractClass = 'SushiSwapAMM'
  const pool = 'SUSHI_WMATIC_WETH';
  const protocol = 'sushiswap';

  // TODO: Rather than deploying from scratch, use same beacon

  await deployAMMVault(
    vaultContractClass,
    pool,
    protocol,
    network,
    deploymentArgs(network, pool, chains[network]!.admin.timelockOwner, chains[network]!.admin.multiSigOwner),
    [chains.matic!.infra.gaslessForwarder!],
    basename(__filename)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});