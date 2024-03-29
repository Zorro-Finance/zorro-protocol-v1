
# Zorro Protocol

Next-gen cross-chain yield aggregation.

The Zorro protcol is a true cross-chain yield aggregator that allows one to take advantage of yield farming opportunities cross-chain without ever leaving your home chain, and features dynamic, market adjusted tokenomics to maximize returns to investors. 

**Website:** https://zorro.finance

**App:** https://app.zorro.finance (Coming soon)

**Docs:** Gitbook (Coming soon)

# Tech stack

* Solidity ^0.8.0
* Typescript
* Hardhat
* OpenZeppelin libraries
* Timelock architecture
* Upgradeable contracts via Beacon proxies
* Chainlink Oracle
* Gnosis Safe
* Openzeppelin Defender

# Mainnet Contracts

_NOTE: Addresses coming soon, and will be updated below once contracts are deployed._

## Avalanche (AVAX)

| Contract                   | Address (Proxy)                            |
|----------------------------|--------------------------------------------|
| ControllerXChain           | 0x1EAFAb82edFb51E0f477C0ADD8639D3a6716EA37 |
| VaultUniswapV2             | 0xFaE44d3d9bcb2c8f35A23349b845971cCD8a951b |
| Treasury                   | 0x0426B99e80783CB9b7C0741C9c9E1d0FAb3f80e7 |
| Timelock                   | 0xb7f176e376B883816BA5C63077b6b2E5579538ae |

## Polygon (Matic)

| Contract                  | Address (Proxy)                            |
|---------------------------|--------------------------------------------|
| ControllerXChain          | 0x95DaB8f1db1ae09B4A983C369F98267Cc48C6F25 |
| VaultUniswapV2            | 0x18cc15d53E4ff864222028F7Acde851F0b65B76b |
| Treasury                  | 0x1cE192d20ccD646d8fF9a47D2C4A364bBD1bea1a |
| Timelock                  | 0xa1Ea1421f9945CcB583eE7083AF6F76503415577 |

## Coming soon

* BNB Chain (BSC)
* Fantom
* Solana

# How to navigate this repo

We follow standard file organization conventions as used by Hardhat and common Solidity community conventions.

# File organization

```bash
.openzeppelin # Proxy contract mapping for upgradeable contracts
artifacts # Hardhat artifacts
cache # Hardhat cache
contracts # Directory of all contract code
--/admin # Contracts related to admin functions such as treasury and governance
--/controllers # Controller contracts for protocol-wide activities, such as cross chain
--/interfaces # All interfaces that all contracts conform to (both internal and 3rd party)
--/libraries # Solidity libraries used to accompany contracts
--/vaults # All vaults (aka investment strategies) that Zorro offers
--Migrations.sol # Truffle migrations file
deployments # Directory containing .lock files describing deployment history
helpers # Directory of all helper functions for deployments etc. and constants such as 3rd party and wallet addresses
scripts # Directory of all scripts (especially contract deployment scripts)
hardhat.config.ts # Hardhat config
package.json # NPM packages that we import from remote
```

## Conventions

All contracts beginning with underscores (e.g. `_VaultBase`) are not deployed contracts, but rather abastract "pieces" 
that we inherit from for the contracts that we DO deploy (e.g. `TraderJoeAMMV1`). This helps keep code more readable
and organized. 

Local variables tend to begin with underscores by convention (e.g. `_amountUSDC`) to reduce confusion with global storage 
variables and increase safety. 

# Code explanations

This section outlines each contract, their purpose, and any other important details.

# Compliance and Safety Features

* Open Zeppelin access control (Ownable, Pausable, Reentrancy guards)
* OpenZeppelin Finance contracts (e.g. PaymentSplitter) for trustless finance
* Timelock controllers (anti-rugpull)
* Rigorous Unit testing (Hardhat Suite)
* Coverage against all common EVM vulnerabilities
* Front running protection
* Pure trustless protocol
* OpenZeppelin Defender monitoring and access controls
* Gnosis Safe Multisig operations

## Audit report
(Coming soon)

# Installation 

To install locally, run:

```bash
yarn
```

# Compiling

NOTE: Ganache CLI is preferred over Ganache desktop and other solutions for local blockchain

```bash
yarn compile
```

# Testing

For tests, run:

```shell
REPORT_GAS=true npx hardhat test
# optionally specify --network <network name>
```

and optionally specify a network, but it will default to `hardhat`.

# Console

```shell
npx hardhat console --network mynetwork

```

# Local hardhat node/chain

```shell
npx hardhat node

```

# Deploy/migrate

```shell
npx hardhat run --network avalanche scripts/deployments/deploy_001.ts
```

All deployments log information/history to _deployments/contracts.lock_ to keep a record of deployments.


## Safety

!! As of writing, deployment files do NOT have any idempotency protection, so please do not re-run migrations
unless you really know what you're doing.

We chose not to use [hardhat-deploy](https://github.com/wighawag/hardhat-deploy/tree/master) to keep things simpler 
and to have more control.

# Upgradeability

To allow for more features and fixes, we implement a _Beacon Proxy_ based on OpenZeppelin Upgradeability standard. 
[Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies)

# Glossary

* **asset token**: Address of the primary token of interest to deposit and farm. Token is the LP token, when liquidity mining
* **reward token**: Address of the farm token (e.g. Cake) that is delivered as a reward (typically the protocol token)
* **vault**: Contract responsible for farming the pool
* **pool**: Contract (usually a 3rd party) providing the investment opportunity (e.g. an LP pool)
* **governor**: An address that has the ability to call administrative functions immediately and bypass the timelock. 
This is most often for emergency pauses on vaults and other time sensistive operations. 
* **timelock**: A contract that can execute admin and governance functions on Zorro contracts but with a delay, so all 
community members can transparently see proposals ahead of time.

# Contact

[@deltakilomilo](https://twitter.com/deltakilomilo/)

[@zorroappcrypto](https://twitter.com/zorroappcrypto)