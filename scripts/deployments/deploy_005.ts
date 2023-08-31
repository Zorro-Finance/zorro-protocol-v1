import { deploymentArgs } from '../../helpers/deployments/vaults/VaultAMM/TraderJoe/deployment';
import { deployAMMVault } from "../../helpers/deployments/vaults/VaultAMM/deployment";
import hre, { upgrades } from 'hardhat';
import { chains } from "../../helpers/constants";
import { basename } from 'path';
import { PublicNetwork } from '../../helpers/types';
import { getLatestBeacon, getMatchingBeaconProxies } from '../../helpers/deployments/utilities';
import { getDefaultProvider } from 'ethers';

async function main() {
  // Init
  const network = hre.network.name as PublicNetwork;

  // Network check
  if (network !== 'avalanche') {
    return;
  }

  // Deploy initial AMM vaults
  const vaultContractClass = 'TraderJoeAMMV1';
  const pool = 'TJ_AVAX_USDC';
  const protocol = 'traderjoe';

  // TEST TODO remove
  const lb = await getLatestBeacon(vaultContractClass, network);
  console.log('latest beacon: ', lb);

  const matchingBPxs = await getMatchingBeaconProxies(vaultContractClass, network);
  console.log('matching proxies: ', matchingBPxs);


  console.log(await upgrades.erc1967.getBeaconAddress('0xd5d9DD5837Fc1ACEBEC207BB5D75858859eadfD0'));

  // await deployAMMVault(
  //   vaultContractClass,
  //   pool,
  //   protocol,
  //   network,
  //   deploymentArgs(network, pool, chains[network]!.admin.timelockOwner, chains[network]!.admin.multiSigOwner),
  //   basename(__filename)
  // );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});