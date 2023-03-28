import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {deploymentArgs} from '../../helpers/deployments/VaultAMM/TraderJoe/deployment';
import { zeroAddress } from "../../helpers/constants";

describe('VaultAMMBase', () => {
    async function deployVaultAMMBaseFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgs('avax', 'TJ_AVAX_USDC', owner.address);

        // Get contract factory
        const Vault = await ethers.getContractFactory('TJ_AVAX_USDC');
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

            // TODO: Check swap paths
            // TODO: Check price feeds

            // Test
            // TODO: Change these to actual values
            expect(asset).to.equal(zeroAddress);
            expect(token0).to.equal(zeroAddress);
            expect(token1).to.equal(zeroAddress);
            expect(farmContract).to.equal(zeroAddress);
            expect(rewardsToken).to.equal(zeroAddress);
            expect(isFarmable).to.equal(true);
            expect(pid).to.equal(0);
            expect(pool).to.equal(zeroAddress);
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

        xit('Should set farm parameters', async () => {
            // TODO
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
});