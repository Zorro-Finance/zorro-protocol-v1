import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {deploymentArgs} from '../../helpers/deployments/VaultAMM/TraderJoe/deployment';
import { zeroAddress, chains } from "../../helpers/constants";

describe('VaultAMMBase', () => {
    async function deployVaultAMMBaseFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgs('avax', 'TJ_AVAX_USDC', owner.address);

        // Get contract factory
        const Vault = await ethers.getContractFactory('TraderJoeAMMV1');
        const vault = await upgrades.deployProxy(Vault, initArgs);
        await vault.deployed();

        return {vault, owner, otherAccount};
    }

    describe('Depoloyment', () => {
        it('Should set the right initial values and owner', async () => { 
            // Prep
            const {vault, owner} = await loadFixture(deployVaultAMMBaseFixture);

            // Run
            const asset = await vault.asset();
            const token0 = await vault.token0();
            const token1 = await vault.token1();
            const farmContract = await vault.farmContract();
            const rewardsToken = await vault.rewardsToken();
            const isFarmable = await vault.isFarmable();
            const pid = await vault.pid();
            const pool = await vault.pool();

            // Check swap paths
            expect(await vault.swapPathLength(chains.avax.tokens.wavax, chains.avax.tokens.usdc)).to.equal(2);
            expect(await vault.swapPathLength(chains.avax.tokens.usdc, chains.avax.tokens.usdc)).to.equal(0);
            expect(await vault.swapPathLength(chains.avax.tokens.wavax, chains.avax.tokens.usdc)).to.equal(2);
            expect(await vault.swapPathLength(chains.avax.tokens.joe, chains.avax.tokens.wavax)).to.equal(2);
            expect(await vault.swapPathLength(chains.avax.tokens.joe, chains.avax.tokens.usdc)).to.equal(2);

            // Check price feeds
            expect(await vault.priceFeeds(chains.avax.tokens.wavax)).to.equal(chains.avax.priceFeeds.avax);
            expect(await vault.priceFeeds(chains.avax.tokens.usdc)).to.equal(chains.avax.priceFeeds.usdc);
            expect(await vault.priceFeeds(chains.avax.tokens.joe)).to.equal(chains.avax.priceFeeds.joe);

            // Test
            expect(asset).to.equal(chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);
            expect(token0).to.equal(chains.avax.tokens.wavax);
            expect(token1).to.equal(chains.avax.tokens.usdc);
            expect(farmContract).to.equal(chains.avax.protocols.traderjoe.masterChef);
            expect(rewardsToken).to.equal(chains.avax.tokens.joe);
            expect(isFarmable).to.equal(true);
            expect(pid).to.equal(chains.avax.protocols.traderjoe.pools.AVAX_USDC.pid);
            expect(pool).to.equal(chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);
        });
    });

    describe('Setters', () => {
        it('Should set key tokens and contract addresses', async () => {
            // Prep
            const {vault, owner} = await loadFixture(deployVaultAMMBaseFixture);
            const newAsset = ethers.Wallet.createRandom().address;
            const newToken0 = ethers.Wallet.createRandom().address;
            const newToken1 = ethers.Wallet.createRandom().address;
            const newPool = ethers.Wallet.createRandom().address;

            // Run
            await vault.setTokens(newAsset, newToken0, newToken1, newPool);            

            // Test
            // TODO: Change these to actual values
            expect(await vault.asset()).to.equal(newAsset);
            expect(await vault.token0()).to.equal(newToken0);
            expect(await vault.token1()).to.equal(newToken1);
            expect(await vault.pool()).to.equal(newPool);
        });

        it('Should set farm parameters', async () => {
            // Prep
            const {vault, owner} = await loadFixture(deployVaultAMMBaseFixture);
            const newFarmContract = ethers.Wallet.createRandom().address;
            const newRewardstoken = ethers.Wallet.createRandom().address;
            const newPid = 1;

            // Run
            await vault.setFarmParams(
                false,
                newFarmContract,
                newRewardstoken,
                newPid
            );
            
            // Test
            expect(await vault.isFarmable()).to.equal(false);
            expect(await vault.farmContract()).to.equal(newFarmContract);
            expect(await vault.rewardsToken()).to.equal(newRewardstoken);
            expect(await vault.pid()).to.equal(newPid);
        });
    });

    describe('Deposits', () => {
        xit('Deposits main asset token', async () => {

        });

        xit('Deposits USD', async () => {

        });
    });

    describe('Withdrawals', () => {
        xit('Withdraws main asset token', async () => {

        });

        xit('Withdraws to USD', async () => {

        });
    });

    describe('Earnings', () => {
        xit('Compounds (reinvests) farm rewards', async () => {

        });
    });

    describe('Utilities', () => {
        xit('Should calculuate amount farmed', async () => {

        });

        xit('Should calculuate pending rewards farmed', async () => {

        });
    });
});