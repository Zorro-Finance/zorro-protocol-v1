import { ethers, upgrades } from "hardhat";
import {deploymentArgs} from '../../helpers/deployments/controllers/ControllerXChain/deployment';
import { recordDeployment, uploadContractToDefender, verifyContract } from "../../helpers/deployments/utilities";
import {basename} from 'path';
import hre from 'hardhat';
import { FormatTypes } from "@ethersproject/abi";
import { PublicNetwork } from "../../helpers/types";

async function main() {
  // Init
  const network = hre.network.name as PublicNetwork;

  // Upgrade XChain controller
  const controllerName = 'ControllerXChain';
  const controllerAddress = '0x144B0148b7613D73FE620c1614e7a6af785a9c61'; // TODO: Consider inferring this somehow
  const Controller = await ethers.getContractFactory(controllerName);
  // Force import because we deleted the .openzeppelin file. TODO: Remove this
  await upgrades.forceImport(
    controllerAddress,
    Controller,
    {
      kind: 'uups',
    }
  );
  const controller = await upgrades.upgradeProxy(
    controllerAddress, 
    Controller,
    {
      kind: 'uups',
    }
  );

  // Block until deployed
  await controller.deployed();

  // Verify contract and send to Etherscan
  await verifyContract(await upgrades.erc1967.getImplementationAddress(controller.address), []);

  // Upload contract to Defender
  await uploadContractToDefender({
    network: network as PublicNetwork,
    address: controller.address,
    name: controllerName,
    abi: Controller.interface.format(FormatTypes.json)! as string
  });

  // Log 
  console.log(
    `ControllerXChain upgraded at ${controller.address}`
  );

  // Record the contract deployment in a lock file
  recordDeployment(
    controllerName,
    network,
    controller.address,
    basename(__filename)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});