import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-etherscan";
import * as dotenv from 'dotenv';

// Preload environment
dotenv.config({path:__dirname + '/.env'});

// Hardhat config
const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.18',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        enabled: true,
        url: 'https://api.avax.network/ext/bc/C/rpc',
      },
    },
    avax: {
      url: 'https://avalanche-mainnet.infura.io',
      chainId: 43114,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!]
    },
    polygon: {
      url: 'https://polygon-mainnet.infura.io',
      chainId: 137,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!]
    },
    bnb: {
      url: 'https://bsc-dataseed.binance.org',
      chainId: 56,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!]
    },
  },
  etherscan: {
    apiKey: {
      avalanche: process.env.SNOWTRACE_API_KEY!,
      polygon: process.env.POLYGONSCAN_API_KEY!,
      bsc: process.env.BSCSCAN_API_KEY!,
    },
  },
};

export default config;
