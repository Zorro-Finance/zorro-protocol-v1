import { ethers } from "hardhat";
import { recordDeployment, uploadContractToDefender, verifyContract } from "../../helpers/deployments/utilities";
import { basename } from 'path';
import hre from 'hardhat';
import { chains } from "../../helpers/constants";
import { FormatTypes } from "@ethersproject/abi";
import { PublicNetwork } from "../../helpers/types";

async function main() {
  // Init
  const network = hre.network.name as PublicNetwork;

  // Check if forwarder contract exists on chain
  const { gaslessForwarder } = chains[network]!.infra;

  if (!gaslessForwarder) {
    // Deploy Forwarder
    const contractName = 'GaslessForwarder';
    const GaslessForwarder = await ethers.getContractFactory(contractName);
    const gaslessForwarderContract = await GaslessForwarder.deploy();

    // Block until deployed
    await gaslessForwarderContract.deployed();

    // Verify contract and send to Etherscan
    await verifyContract(gaslessForwarderContract.address, []);

    // Upload contract to Defender
    await uploadContractToDefender({
      network: network as PublicNetwork,
      address: gaslessForwarderContract.address,
      name: contractName,
      abi: GaslessForwarder.interface.format(FormatTypes.json)! as string
    });


    // Log 
    console.log(
      `GaslessForwarder deployed to ${gaslessForwarderContract.address}`
    );

    // Record the contract deployment in a lock file
    recordDeployment(
      contractName,
      network,
      gaslessForwarderContract.address,
      basename(__filename)
    );
  } else {
    console.log(`Skipping deployment of GaslessForwarder. This chain already has a GSN forwarder at ${gaslessForwarder}`);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});