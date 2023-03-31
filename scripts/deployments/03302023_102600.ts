import { ethers } from "hardhat";
import {writeFile} from 'fs';

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const lockedAmount = ethers.utils.parseEther("0.001");

  const Lock = await ethers.getContractFactory("Lock");
  const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

  await lock.deployed();

  console.log(
    `Lock with ${ethers.utils.formatEther(lockedAmount)}ETH and unlock timestamp ${unlockTime} deployed to ${lock.address}`
  );

  // TODO:  write csv style (append mode). Must include same hiearchy: Vault type > Chain > Protocol > Pool
  writeFile('test.txt', 'hello world', err => {
    if (err) {
      console.error(err);
    }
    // file written successfully
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// TODO: Deploy with UUPS option