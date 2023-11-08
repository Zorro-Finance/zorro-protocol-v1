import { deploymentArgs } from '../../helpers/deployments/vaults/VaultAMM/TraderJoe/deployment';
import { deployVault } from "../../helpers/deployments/vaults/VaultAMM/deployment";
import hre from 'hardhat';
import { chains } from "../../helpers/constants";
import { basename } from 'path';
import { PublicNetwork } from '../../helpers/types';

async function main() {
  // Init
  const network = hre.network.name as PublicNetwork;

  // Deploy initial AMM vaults
  const vaultContractClass = 'VaultUniswapV2';
  const vaultName = 'VaultUniswapV2'

  await deployVault(
    vaultName,
    vaultContractClass,
    network,
    'UniswapV2',
    deploymentArgs(network, chains[network]!.admin.timelockOwner, chains[network]!.admin.multiSigOwner),
    basename(__filename)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});