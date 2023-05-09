import { deploymentArgs } from '../../helpers/deployments/vaults/VaultAMM/TraderJoe/deployment';
import { deployAMMVault } from "../../helpers/deployments/utilities";
import hre from 'hardhat';
import { chains } from "../../helpers/constants";
import { basename } from 'path';
import { PublicNetwork } from '../../helpers/types';

async function main() {
  // Init
  const network = hre.network.name as PublicNetwork;

  // Network check
  if (network !== 'avalanche') {
    return;
  }

  // Deploy initial AMM vaults
  const vaultContractClass = 'TraderJoeAMMV1'
  const pool = 'TJ_AVAX_USDC';
  const protocol = 'traderjoe';

  await deployAMMVault(
    vaultContractClass,
    pool,
    protocol,
    network,
    deploymentArgs(network, pool, chains[network]!.admin.timelockOwner, chains[network]!.admin.multiSigOwner),
    basename(__filename)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});