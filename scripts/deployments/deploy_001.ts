import { ethers, upgrades } from "hardhat";
import {deploymentArgs} from '../../helpers/deployments/controllers/ControllerXChain/deployment';
import { recordDeployment } from "../../helpers/deployments/utilities";
import {basename} from 'path';

async function main() {
  // Deploy XChain controller
  const controllerName = 'ControllerXChain'
  const Controller = await ethers.getContractFactory(controllerName);
  const controller = await upgrades.deployProxy(
    Controller,
    deploymentArgs(network, timelockOwner),
    {
      kind: 'uups',
    }
  );

  // Log 
  console.log(
    `ControllerXChain deployed to ${controller.address}`
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

// TODO: Be able to detect "network" from the args (or ethersjs?)