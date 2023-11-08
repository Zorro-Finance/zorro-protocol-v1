import { ethers, upgrades } from "hardhat";
import { recordDeployment, uploadContractToDefender, verifyContract } from "../../helpers/deployments/utilities";
import {basename} from 'path';
import hre from 'hardhat';
import { chains, team } from "../../helpers/constants";
import { FormatTypes } from "@ethersproject/abi";
import { PublicNetwork } from "../../helpers/types";

async function main() {
  // Init
  const network = hre.network.name as PublicNetwork;

  // Deploy TeamWallet
  const walletName = 'TeamWallet';
  const TeamWallet = await ethers.getContractFactory(walletName);
  const totalShares = ethers.utils.parseEther('1'); // 1e18
  const shares = [
    totalShares.div(2),
    totalShares.div(2),
  ];
  const teamWallet = await upgrades.deployProxy(
    TeamWallet,
    [
      team,
      shares,
      chains[network]!.admin.timelockOwner,
    ],
    {
      kind: 'uups',
    },
  );

  // Block until deployed
  await teamWallet.deployed();

  // Verify contract and send to Etherscan
  await verifyContract(await upgrades.erc1967.getImplementationAddress(teamWallet.address), []);

  // Upload contract to Defender
  await uploadContractToDefender({
    network: network as PublicNetwork,
    address: teamWallet.address,
    name: walletName,
    abi: TeamWallet.interface.format(FormatTypes.json)! as string
});

  // Log 
  console.log(
    `TeamWallet deployed to ${teamWallet.address}`
  );

  // Record the contract deployment in a lock file
  recordDeployment(
    walletName,
    network,
    teamWallet.address,
    basename(__filename)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});